use crate::core::*;
use crate::silo::SiloResolver;
use std::path::PathBuf;
use std::fs;
use std::collections::HashMap;

#[derive(Clone, Debug)]
pub struct HardwareJob {
    pub testbench: String,
    pub param_set: String,
    pub simulator: String,
    pub silo_dir: PathBuf,
    pub artifact_paths: HashMap<String, PathBuf>,
    pub external_deps: Vec<PathBuf>, // Strictly for inputs like .a files
    pub rtl_inputs: Vec<PathBuf>,
}

pub fn resolve_hardware(
    config: &Config,
    lua: &mlua::Lua,
    binding: &Experiment,
    silo: &SiloResolver,
) -> anyhow::Result<Vec<HardwareJob>> {
    let mut jobs = Vec::new();
    let root = std::env::current_dir()?;

    let tb = config.testbenches.get(&binding.testbench)
        .ok_or_else(|| anyhow::anyhow!("TB '{}' not found", binding.testbench))?;

    for ps_name in &binding.param_sets {
        let ps = config.param_sets.get(ps_name)
            .ok_or_else(|| anyhow::anyhow!("ParamSet '{}' not found", ps_name))?;

        let hw_common_dir = silo.hw_common_dir(&tb.name, ps_name);
        fs::create_dir_all(&hw_common_dir)?;

        if let Some(arc_key) = config.hooks.testbench.get(&(tb.name.clone(), TestbenchHook::PreCompile)) {
            let func: mlua::Function = lua.registry_value(&*arc_key)
                .map_err(|e| anyhow::anyhow!("Lua Registry: {}", e))?;
            
            let ctx = lua.create_table().map_err(|e| anyhow::anyhow!(e.to_string()))?;
            ctx.set("common_dir", hw_common_dir.to_string_lossy())
                .map_err(|e| anyhow::anyhow!(e.to_string()))?;
            
            func.call::<()>(ctx).map_err(|e| anyhow::anyhow!("Hook: {}", e))?;
        }

        let mut replacements = tb.vars.clone();
        replacements.insert("PROJ_DIR".to_string(), root.to_string_lossy().to_string());
        replacements.insert("BUILD_DIR".to_string(), silo.root.to_string_lossy().to_string());
        replacements.insert("COMMON_DIR".to_string(), hw_common_dir.to_string_lossy().to_string());

        let original_content = fs::read_to_string(root.join(&tb.filelist))?;
        let mut rendered_content = original_content;
        for (key, val) in &replacements {
            rendered_content = rendered_content.replace(&format!("$({})", key), val);
        }

        let resolved_f_path = hw_common_dir.join("resolved.f");
        fs::write(&resolved_f_path, &rendered_content)?;

        let mut svh = String::from("// Generated\n");
        svh.push_str("`ifndef HARNESS_PARAMS_SVH\n");
        svh.push_str("`define HARNESS_PARAMS_SVH\n\n");

        for (k, v) in &ps.defines { 
            svh.push_str(&format!("`define {} {}\n", k, v)); 
        }

        svh.push_str("\n`endif // HARNESS_PARAMS_SVH\n");

        fs::write(hw_common_dir.join("harness_params.svh"), svh)?;

        let mut rtl_inputs = Vec::new();
        rtl_inputs.push(hw_common_dir.join("harness_params.svh"));
        rtl_inputs.push(resolved_f_path.clone());

        for line in rendered_content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with("//") || line.starts_with('+') || line.starts_with('-') {
                continue;
            }
            let path = PathBuf::from(line);
            if path.exists() {
                rtl_inputs.push(path);
            }
        }

        for sim_name in &binding.simulators {
            let silo_dir = silo.hw_dir(&tb.name, ps_name, sim_name);
            fs::create_dir_all(&silo_dir)?;

            fs::write(silo_dir.join("top.f"), format!(
                "+incdir+{}\n-f {}\n",
                hw_common_dir.canonicalize()?.display(),
                resolved_f_path.canonicalize()?.display()
            ))?;

            let mut artifact_paths = HashMap::new();
            for art in &config.simulators[sim_name].outputs {
                artifact_paths.insert(art.name.clone(), silo_dir.join(&art.filename));
            }

            jobs.push(HardwareJob {
                testbench: tb.name.clone(),
                param_set: ps_name.clone(),
                simulator: sim_name.clone(),
                silo_dir,
                artifact_paths,
                external_deps: tb.sw_deps.clone(), 
                rtl_inputs: rtl_inputs.clone(),
            });
        }
    }
    Ok(jobs)
}
