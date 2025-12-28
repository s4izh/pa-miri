use crate::core::*;
use crate::silo::SiloResolver;
use std::fs;
use std::path::PathBuf;
use std::collections::HashMap;

#[derive(Clone)]
pub struct HardwareJob {
    pub processor: String,
    pub variant: String,
    pub testbench: String,
    pub simulator: String,
    pub silo_dir: PathBuf,
    pub artifact_paths: HashMap<String, PathBuf>,
}

pub fn resolve_hardware(
    config: &Config,
    binding: &Binding,
    silo: &crate::silo::SiloResolver,
) -> anyhow::Result<Vec<HardwareJob>> {
    let mut jobs = Vec::new();

    for p_name in &binding.processors {
        let proc = config.processors.get(p_name)
            .ok_or_else(|| anyhow::anyhow!("Processor '{}' defined in binding '{}' was not found in config. Defined processors: {:?}", p_name, binding.name, config.processors.keys()))?;

        for v_name in &binding.variants {
            let variant = proc.variants.get(v_name)
                .ok_or_else(|| anyhow::anyhow!("Variant '{}' not found for processor '{}'. Available variants: {:?}", v_name, p_name, proc.variants.keys()))?;

            for tb_name in &binding.testbenches {
                let tb = config.testbenches.get(tb_name)
                    .ok_or_else(|| anyhow::anyhow!("Testbench '{}' not found in config.", tb_name))?;

                for sim_name in &binding.simulators {
                    let sim = config.simulators.get(sim_name)
                        .ok_or_else(|| anyhow::anyhow!("Simulator '{}' not found in config.", sim_name))?;

                    let silo_dir = silo.hw_dir(p_name, v_name, tb_name, sim_name);
                    std::fs::create_dir_all(&silo_dir)?;

                    if !proc.rtl_filelist.exists() {
                        anyhow::bail!("RTL filelist missing: {:?}", proc.rtl_filelist);
                    }
                    if !tb.filelist.exists() {
                        anyhow::bail!("Testbench filelist missing: {:?}", tb.filelist);
                    }

                    let mut params = proc.base_params.clone();
                    params.extend(variant.params.clone());
                    let mut svh = String::from("// harness params: DO NOT EDIT MANUALLY\n");
                    for (k, v) in params { svh.push_str(&format!("`define {} {}\n", k, v)); }
                    std::fs::write(silo_dir.join("harness_params.svh"), svh)?;

                    let top_f = format!("+incdir+{}\n-f {}\n", 
                        silo_dir.canonicalize()?.display(),
                        // proc.rtl_filelist.canonicalize()?.display(),
                        tb.filelist.canonicalize()?.display());
                    std::fs::write(silo_dir.join("top.f"), top_f)?;

                    let mut artifact_paths = std::collections::HashMap::new();
                    for art in &sim.outputs {
                        artifact_paths.insert(art.name.clone(), silo_dir.join(&art.filename));
                    }

                    jobs.push(HardwareJob {
                        processor: p_name.clone(),
                        variant: v_name.clone(),
                        testbench: tb_name.clone(),
                        simulator: sim_name.clone(),
                        silo_dir,
                        artifact_paths,
                    });
                }
            }
        }
    }
    Ok(jobs)
}
