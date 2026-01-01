use crate::core::*;
use crate::hw::HardwareJob;
use crate::sw::SoftwareJob;
use crate::silo::SiloResolver;
use std::path::PathBuf;
use std::collections::HashMap;

pub struct SimJob {
    pub experiment: String,
    pub hw_id: String,
    pub silo_dir: PathBuf,
    pub dependencies: Vec<PathBuf>,
}

pub fn resolve_simulations(
    config: &Config,
    experiment: &Experiment,
    hw_jobs: &[HardwareJob],
    sw_jobs: &[SoftwareJob],
    silo: &SiloResolver,
) -> anyhow::Result<Vec<SimJob>> {
    let mut jobs = Vec::new();
    let root = std::env::current_dir()?;
    let tb_spec = &config.testbenches[&experiment.testbench];

    for hw in hw_jobs {
        let sw_configs: Vec<Option<&SoftwareJob>> = if sw_jobs.is_empty() { vec![None] } else { sw_jobs.iter().map(Some).collect() };

        for sw_opt in sw_configs {
            let (sim_dir, suite_plusargs) = if let Some(sw) = sw_opt {
                let suite = &config.suites[&sw.suite_name];
                (silo.sim_dir(&experiment.name, &hw.testbench, &hw.param_set, &hw.simulator, &suite.name, &sw.rel_path), suite.plusargs.clone())
            } else {
                (silo.root.join("sim").join(&experiment.name).join(&hw.testbench).join(&hw.param_set).join(&hw.simulator).join("standalone"), vec![])
            };

            std::fs::create_dir_all(&sim_dir)?;
            let ps_spec = &config.param_sets[&hw.param_set];
            let sim_spec = &config.simulators[&hw.simulator];

            let mut cmd = ps_spec.sim_templates.get(&hw.simulator)
                .unwrap_or(if !tb_spec.run_template.is_empty() { &tb_spec.run_template } else { &sim_spec.default_run_rule }).clone();

            let mut deps = Vec::new();
            for (logical, path) in &hw.artifact_paths {
                cmd = cmd.replace(&format!("${}", logical), &root.join(path).to_string_lossy());
                deps.push(path.clone());
            }

            if let Some(sw) = sw_opt {
                for (logical, path) in &sw.artifacts {
                    cmd = cmd.replace(&format!("${}", logical), &root.join(path).to_string_lossy());
                    deps.push(path.clone());
                }
            }

            let mut pa = ps_spec.plusargs.clone();
            pa.extend(suite_plusargs);
            cmd = cmd.replace("$plusargs", &pa.join(" "));

            let final_cmd = regex::Regex::new(r"\$\w+").unwrap().replace_all(&cmd, "").to_string();
            let script_path = sim_dir.join("run.sh");
            std::fs::write(&script_path, format!("#!/usr/bin/env bash\n\n{}\n", final_cmd))?;

            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = std::fs::set_permissions(&script_path, std::fs::Permissions::from_mode(0o755));
            }

            jobs.push(SimJob {
                experiment: experiment.name.clone(),
                hw_id: format!("{}/{}", hw.testbench, hw.param_set),
                silo_dir: sim_dir,
                dependencies: deps,
            });
        }
    }
    Ok(jobs)
}
