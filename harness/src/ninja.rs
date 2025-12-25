use crate::{core::Job, silo::SiloResolver};
use ninja_writer::{Ninja, BuildVariables, Variables, RuleRef};
use std::collections::{HashMap, HashSet};

pub fn generate(jobs: &[Job]) -> anyhow::Result<String> {
    let writer = Ninja::new(); 
    let res = SiloResolver::new();
    let root = std::env::current_dir()?;

    let mut defined_hw = HashSet::new();
    let mut defined_sw = HashSet::new();
    let mut defined_tools = HashSet::new();

    let mut dynamic_rules: HashMap<String, RuleRef> = HashMap::new();

    let make_rule = writer.rule("external_make", "make -C $dir");

    let run_sim_rule = writer.rule("run_sim", 
        "mkdir -p $silo && cd $silo && echo '$bin_abs +ROM_FILE=$rom_abs +SRAM_FILE=$sram_abs +VCD_FILE=waveform.fst' > cmdline && $bin_abs +ROM_FILE=$rom_abs +SRAM_FILE=$sram_abs +VCD_FILE=waveform.fst > sim.log 2>&1"
    );

    for j in jobs {
        let mut extra_ld_flags = String::new();
        let mut hw_deps = vec![res.hw_dir(j).join("top.f").to_str().unwrap().to_string()];

        if j.tb.name == "cosim" {
            let lib_path_rel = "cosim/cosim_dpi.a";
            if !defined_tools.contains(lib_path_rel) {
                make_rule.build([lib_path_rel])
                    .variable("dir", "cosim");
                defined_tools.insert(lib_path_rel.to_string());
            }
            hw_deps.push(lib_path_rel.to_string());
            extra_ld_flags = format!("{}", root.join(lib_path_rel).display());
        }

        let hw_dir = res.hw_dir(j);
        let hw_bin = res.hw_bin(j);
        let hw_bin_str = hw_bin.to_str().unwrap();

        if !defined_hw.contains(hw_bin_str) {
            let sim_rule_name = format!("{}_compile", j.sim.name);
            
            if !dynamic_rules.contains_key(&sim_rule_name) {
                let r = writer.rule(&sim_rule_name, &j.sim.compile_rule);
                dynamic_rules.insert(sim_rule_name.clone(), r);
            }

            let mut p_flags = String::new();
            for (k, v) in &j.final_params { 
                p_flags.push_str(&format!("{}{}={} ", j.sim.param_prefix, k, v)); 
            }

            let rule_ref = dynamic_rules.get(&sim_rule_name).unwrap();
            
            rule_ref.build([hw_bin_str])
                .with(hw_deps) 
                .variable("params", p_flags)
                .variable("filelist", hw_dir.join("top.f").to_str().unwrap())
                .variable("top_module", &j.tb.top_module)
                .variable("out_dir", hw_dir.to_str().unwrap())
                .variable("ld_flags", extra_ld_flags);
            
            defined_hw.insert(hw_bin_str.to_string());
        }

        let sw_dir = res.sw_dir(j);
        let sw_key = sw_dir.to_str().unwrap();

        if !defined_sw.contains(sw_key) {
            std::fs::create_dir_all(&sw_dir)?;

            for action in &j.builder.actions {
                let rule_name = format!("{}_{}", j.builder.name, action.name);
                
                if !dynamic_rules.contains_key(&rule_name) {
                    let r = writer.rule(&rule_name, &action.command);
                    dynamic_rules.insert(rule_name.clone(), r);
                }

                let inputs: Vec<String> = if action.inputs.is_empty() {
                    vec![j.program.source.to_str().unwrap().to_string()]
                } else {
                    action.inputs.iter()
                        .map(|f| sw_dir.join(f).to_str().unwrap().to_string())
                        .collect()
                };

                let outputs: Vec<String> = action.outputs.iter()
                    .map(|f| sw_dir.join(f).to_str().unwrap().to_string())
                    .collect();

                let rule_ref = dynamic_rules.get(&rule_name).unwrap();
                
                let mut build_edge = rule_ref.build(outputs)
                    .with(inputs)
                    .variable("out_dir", sw_key); 

                for (var_k, var_v) in &j.variables {
                    build_edge = build_edge.variable(var_k, var_v);
                }
            }
            defined_sw.insert(sw_key.to_string());
        }

        let rom_hex = sw_dir.join("rom.hex");
        let sram_hex = sw_dir.join("sram.hex");
        let sim_dir = res.sim_dir(j);
        
        run_sim_rule.build([sim_dir.join("sim.log").to_str().unwrap()])
            .with([hw_bin_str, rom_hex.to_str().unwrap(), sram_hex.to_str().unwrap()])
            .variable("silo", sim_dir.to_str().unwrap())
            .variable("bin_abs", root.join(&hw_bin).to_str().unwrap())
            .variable("rom_abs", root.join(&rom_hex).to_str().unwrap())
            .variable("sram_abs", root.join(&sram_hex).to_str().unwrap());
    }

    Ok(writer.to_string())
}
