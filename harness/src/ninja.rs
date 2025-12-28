// harness/src/ninja.rs
use crate::core::*;
use crate::hw::HardwareJob;
use crate::sim::SimJob;
use crate::sw::SoftwareJob;
use std::collections::HashSet;

pub fn generate(
    config: &Config,
    hw_jobs: &[HardwareJob],
    sw_jobs: &[SoftwareJob],
    sim_jobs: &[SimJob],
) -> String {
    let mut n = String::new();
    let mut seen_rules = HashSet::new();

    n.push_str("# ==========================================\n# RULES\n# ==========================================\n\n");

    // HW Compiler Rules
    for sim in config.simulators.values() {
        let rule_name = format!("{}_compile", sim.name);
        if seen_rules.insert(rule_name.clone()) {
            n.push_str(&format!(
                "rule {}\n  command = {}\n\n",
                rule_name, sim.compile_rule
            ));
        }
    }

    // SW Tool Rules
    for tool in config.tools.values() {
        for action in &tool.actions {
            let rule_name = format!("{}_{}", tool.name, action.name);
            if seen_rules.insert(rule_name.clone()) {
                n.push_str(&format!(
                    "rule {}\n  command = {}\n\n",
                    rule_name, action.command
                ));
            }
        }
    }

    n.push_str("rule run_sim_script\n  command = cd $dir && chmod +x run.sh && ./run.sh > sim.log 2>&1\n\n");

    n.push_str("# ==========================================\n# HARDWARE NODES\n# ==========================================\n\n");
    for job in hw_jobs {
        let outs = job
            .artifact_paths
            .values()
            .map(|p| p.to_string_lossy())
            .collect::<Vec<_>>()
            .join(" ");
        n.push_str(&format!(
            "build {}: {}_compile {}/top.f\n",
            outs,
            job.simulator,
            job.silo_dir.display()
        ));
        n.push_str(&format!("  filelist = {}/top.f\n", job.silo_dir.display()));
        n.push_str(&format!("  out_dir = {}\n\n", job.silo_dir.display()));
    }

    n.push_str("# ==========================================\n# SOFTWARE NODES\n# ==========================================\n\n");
    for job in sw_jobs {
        n.push_str(&format!("# Program: {}\n", job.rel_path.display()));
        for task in &job.actions {
            let outs = task
                .outputs
                .iter()
                .map(|p| p.to_string_lossy())
                .collect::<Vec<_>>()
                .join(" ");
            let ins = task
                .inputs
                .iter()
                .map(|p| p.to_string_lossy())
                .collect::<Vec<_>>()
                .join(" ");
            n.push_str(&format!("build {}: {} {}\n", outs, task.rule_name, ins));
            for (k, v) in &task.variables {
                n.push_str(&format!("  {} = {}\n", k, v));
            }
            n.push_str("\n");
        }
    }

    n.push_str("# ==========================================\n# SIMULATION NODES\n# ==========================================\n\n");

    for job in sim_jobs {
        let root = std::env::current_dir().unwrap();
        let abs_sim_dir = root.join(&job.silo_dir);
        let log = job.silo_dir.join("sim.log");

        let deps = job
            .dependencies
            .iter()
            .map(|p| p.to_string_lossy().to_string())
            .collect::<Vec<_>>()
            .join(" ");

        n.push_str(&format!(
            "build {}: run_sim_script {}\n",
            log.display(),
            deps
        ));
        // use absolute path for the directory context
        n.push_str(&format!("  dir = {}\n\n", abs_sim_dir.display()));
    }

    n
}
