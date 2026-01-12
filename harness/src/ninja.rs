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

    n.push_str("# RULES\n");
    
    for sim in config.simulators.values() {
        let rule_name = format!("{}_compile", sim.name);
        if seen_rules.insert(rule_name.clone()) {
            n.push_str(&format!("rule {}\n  command = {}\n\n", rule_name, sim.compile_rule));
        }
    }

    for tool in config.tools.values() {
        for action in &tool.actions {
            let rule_name = format!("{}_{}", tool.name, action.name);
            if seen_rules.insert(rule_name.clone()) {
                n.push_str(&format!("rule {}\n  command = {}\n\n", rule_name, action.command));
            }
        }
    }

    n.push_str("rule run_sim_script\n  command = cd $dir && chmod +x run.sh && ./run.sh > sim.log 2>&1\n\n");

    n.push_str("# CUSTOM TASKS\n");
    for task in &config.tasks {
        let rule_name = format!("task_{}", task.name);
        n.push_str(&format!("rule {}\n  command = {}\n\n", rule_name, task.command));
        
        let outs = task.outputs.iter().map(|p| p.to_string_lossy()).collect::<Vec<_>>().join(" ");
        let ins = task.inputs.iter().map(|p| p.to_string_lossy()).collect::<Vec<_>>().join(" ");
        
        n.push_str(&format!("build {}: {} {}\n", outs, rule_name, ins));
        for (k, v) in &task.vars {
            n.push_str(&format!("  {} = {}\n", k, v));
        }
        n.push_str("\n");
    }

    n.push_str("# HARDWARE\n");
    for job in hw_jobs {
        let outs = job.artifact_paths.values().map(|p| p.to_string_lossy()).collect::<Vec<_>>().join(" ");
        
        // dependencies are relative for Ninja's graph tracking
        let mut deps = vec![job.silo_dir.join("top.f").to_string_lossy().to_string()];
        for rtl_file in &job.rtl_inputs {
            deps.push(rtl_file.to_string_lossy().to_string());
        }

        for ext_dep in &job.external_deps {
            deps.push(ext_dep.to_string_lossy().to_string());
        }

        n.push_str(&format!("build {}: {}_compile {}\n", outs, job.simulator, deps.join(" ")));
        // n.push_str(&format!("  filelist = {}/top.f\n  out_dir = {}\n\n", job.silo_dir.display(), job.silo_dir.display()));
        
        // use absolute paths for command variables ($filelist, $out_dir)
        // this ensures containers (which might have a different CWD) can find the files.
        let abs_silo = std::env::current_dir().unwrap().join(&job.silo_dir);
        n.push_str(&format!("  filelist = {}/top.f\n  out_dir = {}\n\n", abs_silo.display(), abs_silo.display()));
    }

    n.push_str("# SOFTWARE\n");
    for job in sw_jobs {
        for task in &job.actions {
            let outs = task.outputs.iter().map(|p| p.to_string_lossy()).collect::<Vec<_>>().join(" ");
            let ins = task.inputs.iter().map(|p| p.to_string_lossy()).collect::<Vec<_>>().join(" ");
            n.push_str(&format!("build {}: {} {}\n", outs, task.rule_name, ins));
            for (k, v) in &task.variables {
                n.push_str(&format!("  {} = {}\n", k, v));
            }
            n.push_str("\n");
        }
    }

    n.push_str("# SIMULATIONS\n");
    for job in sim_jobs {
        let log = job.silo_dir.join("sim.log");
        
        let deps = job.dependencies.iter().map(|p| p.to_string_lossy().to_string()).collect::<Vec<_>>().join(" ");
        
        n.push_str(&format!("build {}: run_sim_script {}\n", log.display(), deps));
        n.push_str(&format!("  dir = {}\n\n", std::env::current_dir().unwrap().join(&job.silo_dir).display()));
    }
    
    n
}
