mod core;
mod sw;
mod ninja;
mod silo;
mod hw;
mod sim;
mod cli;
mod analysis;
mod lua_engine;
// mod discovery;

use crate::core::*;
use std::collections::{HashMap,BTreeMap};

use clap::{CommandFactory, Parser};
use std::path::{Path, PathBuf};
use std::process::Command;
use regex::Regex;

// use colored::Colorize;

use crate::cli::{Cli, Commands};
use crate::core::Config;
use std::sync::Arc;

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let proj_root: PathBuf = std::env::var("PROJ_DIR")?.into();

    let lua_path = proj_root.join("harness.lua");
    
    let (config, lua, silo) = if !lua_path.exists() {
        let (c, s) = setup_config(&proj_root)?;
        (c, Arc::new(mlua::Lua::new()), s)
    } else {
        let (c, l) = lua_engine::load_config(&lua_path)?;
        let s = silo::SiloResolver::new(c.build_dir.clone().into());
        (c, l, s)
    };

    match &cli.command {
        Commands::Gen => {
            println!("Discovering targets...");
            let ninja_path = proj_root.join("build.ninja");
            let (hw, sw, sim) = resolve_all_jobs(&config, &lua, &silo)?;
            std::fs::write(&ninja_path, ninja::generate(&config, &hw, &sw, &sim))?;
            println!("Ninja file generated at: {}", ninja_path.display());
        }

        cli::Commands::List => {
            let (all_hw, all_sw, _) = resolve_all_jobs(&config, &lua, &silo)?;
            println!("\n--- Hardware Configurations ---");
            for h in all_hw {
                println!("  - {:<20} (Params: {:<10}, Sim: {})", h.testbench, h.param_set, h.simulator);
            }
            println!("\n--- Software Suites ---");
            for s in all_sw {
                println!("  - Suite: {:<10} Program: {}", s.suite_name, s.rel_path.display());
            }
        }

        cli::Commands::Simulate(args) | cli::Commands::Compile(args) | cli::Commands::Analyze(args) => {
            let (all_hw, all_sw, all_sim) = resolve_all_jobs(&config, &lua, &silo)?;

            let exp_name = match &args.experiment {
                Some(name) => name,
                None => {
                    println!("Available Experiments:");
                    for b in &config.experiments { println!("  - {}", b.name); }
                    return Ok(());
                }
            };
            let target_exp = config.experiments.iter().find(|b| &b.name == exp_name)
                .ok_or_else(|| anyhow::anyhow!("Experiment '{}' not found.", exp_name))?;

            let sw_re = Regex::new(args.sw.as_deref().unwrap_or(".*"))?; // Searchable
            let hw_filter = &args.hw;  // Categorical (Exact)
            let sim_filter = &args.sim; // Categorical (Exact)

            match &cli.command {
                Commands::Simulate(args) | Commands::Analyze(args) => {
                    let mut targets = Vec::new();
                    for s in all_sim.iter().filter(|s| &s.experiment == exp_name) {
                        let match_hw = hw_filter.as_ref().map_or(true, |f| s.hw_id.contains(f)); 
                        let match_sim = sim_filter.as_ref().map_or(true, |f| s.silo_dir.to_string_lossy().contains(f));
                        let match_sw = sw_re.is_match(&s.silo_dir.to_string_lossy());

                        if match_hw && match_sim && match_sw {
                            targets.push(s.silo_dir.join("sim.log").to_string_lossy().to_string());
                        }
                    }

                    if matches!(cli.command, Commands::Simulate(_)) && !targets.is_empty() {
                        let ninja_str = ninja::generate(&config, &all_hw, &all_sw, &all_sim);
                        std::fs::write(proj_root.join("build.ninja"), ninja_str)?;
                        let _ = run_ninja(&proj_root, &targets, true, None);
                    }
                    analysis::run_analysis(&proj_root, &targets, args.baseline.as_deref())?;
                }

                Commands::Compile(_) => {
                    let mut hw_targets = std::collections::HashSet::new();
                    let mut sw_targets = std::collections::HashSet::new();

                    // hardware filtering (exact)
                    for h in &all_hw {
                        let is_for_exp = h.testbench == target_exp.testbench && target_exp.param_sets.contains(&h.param_set);
                        let is_hw_match = hw_filter.as_ref().map_or(true, |f| &h.param_set == f);
                        let is_sim_match = sim_filter.as_ref().map_or(true, |f| &h.simulator == f);

                        if is_for_exp && is_hw_match && is_sim_match {
                            for path in h.artifact_paths.values() {
                                hw_targets.insert(path.to_string_lossy().to_string());
                            }
                        }
                    }

                    // software filtering (searchable regex)
                    for suite_name in &target_exp.suites {
                        for sw_job in all_sw.iter().filter(|j| &j.suite_name == suite_name) {
                            if sw_re.is_match(&sw_job.rel_path.to_string_lossy()) {
                                for path in sw_job.artifacts.values() {
                                    sw_targets.insert(path.to_string_lossy().to_string());
                                }
                            }
                        }
                    }

                    let final_targets: Vec<String> = hw_targets.into_iter().chain(sw_targets).collect();
                    if !final_targets.is_empty() {
                        let ninja_str = ninja::generate(&config, &all_hw, &all_sw, &all_sim);
                        std::fs::write(proj_root.join("build.ninja"), ninja_str)?;
                        let _ = run_ninja(&proj_root, &final_targets, false, None);
                    }
                }
                _ => unreachable!()
            }
        }

        cli::Commands::Clean(args) => {
            let build_root = proj_root.join(&silo.root);
            let has_any_filter = args.experiment.is_some() || args.hw.is_some() || args.sw.is_some() || args.sim.is_some();

            if !has_any_filter {
                if build_root.exists() { std::fs::remove_dir_all(&build_root)?; }
                let _ = std::fs::remove_file(proj_root.join("build.ninja"));
                println!("Full clean complete.");
                return Ok(());
            }

            let (all_hw, all_sw, all_sim) = resolve_all_jobs(&config, &lua, &silo)?;
            let sw_re = Regex::new(args.sw.as_deref().unwrap_or(".*"))?;

            // clean simulations (experiment exact)
            for s in all_sim {
                let match_exp = args.experiment.as_ref().map_or(true, |f| &s.experiment == f);
                let match_sw = sw_re.is_match(&s.silo_dir.to_string_lossy());
                let match_hw = args.hw.as_ref().map_or(true, |f| s.silo_dir.to_string_lossy().contains(f));

                if match_exp && match_sw && match_hw && s.silo_dir.exists() {
                    std::fs::remove_dir_all(&s.silo_dir)?;
                }
            }

            // clean software (suite/program searchable)
            if args.sw.is_some() {
                for suite_name in config.suites.keys() {
                    if sw_re.is_match(suite_name) {
                        let suite_dir = build_root.join("sw").join(suite_name);
                        if suite_dir.exists() { std::fs::remove_dir_all(&suite_dir)?; }
                    }
                }
                for sw_job in all_sw {
                    if sw_re.is_match(&sw_job.rel_path.to_string_lossy()) {
                        let sw_silo = silo.sw_dir(&sw_job.suite_name, &sw_job.rel_path);
                        if sw_silo.exists() { std::fs::remove_dir_all(&sw_silo)?; }
                    }
                }
            }

            // clean hardware (exact)
            for h in all_hw {
                let match_hw = args.hw.as_ref().map_or(true, |f| &h.param_set == f);
                let match_sim = args.sim.as_ref().map_or(true, |f| &h.simulator == f);
                if match_hw && match_sim && h.silo_dir.exists() {
                    std::fs::remove_dir_all(&h.silo_dir)?;
                }
            }
        }

        cli::Commands::Completions { shell } => {
            let mut cmd = cli::Cli::command();
            let name = cmd.get_name().to_string();
            clap_complete::generate(*shell, &mut cmd, name, &mut std::io::stdout());
        }
    }

    Ok(())
}

fn detect_proj_root() -> Option<PathBuf> {
    let mut current = std::env::current_dir().ok()?;
    loop {
        if current.join("sim").is_dir() && current.join("rtl").is_dir() {
            return Some(current);
        }
        if !current.pop() { break; }
    }
    None
}

fn run_ninja(
    root: &Path, 
    targets: &[String], 
    keep_going: bool, 
    nprocs: Option<usize>
) -> anyhow::Result<()> {
    let mut cmd = Command::new("ninja");
    cmd.current_dir(root).args(targets);

    let jobs = match nprocs {
        Some(j) => j,
        None => std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(1),
    };

    println!("Running up to jobs {} in parallel", jobs);
    
    cmd.arg("-j").arg(jobs.to_string());

    if keep_going {
        // -k 0 tells Ninja to keep going as much as possible
        cmd.arg("-k").arg("0"); 
    }

    // 3. Execute
    let status = cmd.status()?;
    if !status.success() && !keep_going {
        anyhow::bail!("Ninja failed with exit code: {:?}", status.code());
    }
    
    Ok(())
}

fn resolve_all_jobs(config: &Config, lua: &mlua::Lua, silo: &silo::SiloResolver)
-> anyhow::Result<(Vec<hw::HardwareJob>, Vec<sw::SoftwareJob>, Vec<sim::SimJob>)>
{
    let mut unique_hw = HashMap::new();
    let mut all_sw = Vec::new();
    let mut all_sim = Vec::new();

    let mut suite_map = HashMap::new();
    for name in config.suites.keys() {
        let jobs = sw::resolve_suite(config, name, silo)?;
        suite_map.insert(name.clone(), jobs.clone());
        all_sw.extend(jobs);
    }

    for exp in &config.experiments {
        let hw_for_exp = hw::resolve_hardware(config, lua, exp, silo)?;
        for job in &hw_for_exp { unique_hw.insert(job.silo_dir.clone(), job.clone()); }

        let mut sw_for_exp = Vec::new();
        for s_name in &exp.suites {
            if let Some(j) = suite_map.get(s_name) { sw_for_exp.extend(j.clone()); }
        }

        all_sim.extend(sim::resolve_simulations(config, exp, &hw_for_exp, &sw_for_exp, silo)?);
    }

    Ok((unique_hw.into_values().collect(), all_sw, all_sim))
}

fn setup_config(root: &Path) -> anyhow::Result<(Config, silo::SiloResolver)> {
    let mut config = Config::new();

    let riscv_gcc = Tool {
        name: "riscv_gcc".into(),
        actions: vec![
            Action {
                name: "compile".into(),
                command: "riscv32-none-elf-gcc $flags -Iprograms -c $in -o $obj".into(),
                inputs: vec![],
                outputs: vec![Artifact { 
                    name: "obj".into(), filename: "prog.o".into()
                }],
            },
            Action {
                name: "link".into(),
                command: "riscv32-none-elf-gcc $flags -T $ld -nostdlib -Wl,-Map,$map $obj -o $elf".into(),
                inputs: vec!["obj".into()],
                outputs: vec![
                    Artifact { name: "elf".into(), filename: "prog.elf".into() },
                    Artifact { name: "map".into(), filename: "prog.map".into() }
                ],
            },
            Action {
                name: "rom".into(),
                command: "riscv32-none-elf-objcopy -O verilog --verilog-data-width 4 --only-section=.text* $elf $out_dir/rom.tmp && \
                    cat $out_dir/rom.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $rom && \
                    rm $out_dir/rom.tmp".into(),
                inputs: vec!["elf".into()],
                outputs: vec![ Artifact { name: "rom".into(), filename: "rom.hex".into() } ],
            },
            Action {
                name: "sram".into(),
                command: "riscv32-none-elf-objcopy -O verilog --verilog-data-width 4 --only-section=.data* --only-section=.sdata* --only-section=.bss* --only-section=.sbss* $elf $out_dir/sram.tmp && \
                    cat $out_dir/sram.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $sram && \
                    rm $out_dir/sram.tmp".into(),
                inputs: vec!["elf".into()],
                outputs: vec![ Artifact { name: "sram".into(), filename: "sram.hex".into() } ],
            },
        ],
    };

    config.tools.insert("riscv_gcc".into(), riscv_gcc);

    config.suites.insert("isa".into(), Suite {
        name: "isa".into(),
        base_dir: PathBuf::from("programs/tohost_tests"),
        pattern: "**/*.s".into(),
        tool: "riscv_gcc".into(),
        plusargs: Vec::new(),
        default_vars: HashMap::from([
            ("flags".into(), "-march=rv32i -mabi=ilp32".into()),
            ("ld".into(), "programs/link.ld".into()),
        ]),
        program_overrides: HashMap::new(),
        sw_deps: vec![]
    });

    config.simulators.insert("verilator".into(), Simulator {
        name: "verilator".into(),
        compile_rule: "verilator -j 8 --cc --binary --build -O3 --trace-fst --trace-structs --timing -f $filelist --top-module top_tb_wrapper --Mdir $out_dir -o Vtop".into(),
        outputs: vec![Artifact { name: "bin".into(), filename: "Vtop".into() }],
        default_run_rule: "$bin $plusargs".into(),
    });

    config.testbenches.insert("rv_pa3.anyrom".into(), Testbench {
        name: "rv_pa3.anyrom".into(),
        filelist: PathBuf::from("sim/rv_pa3/anyrom/filelist.f"),
        run_template: "$bin $plusargs +ROM_FILE=$rom +SRAM_FILE=$sram +TIMEOUT=10000".into(),
        sw_deps: vec![],
        ..Default::default()
    });

    config.testbenches.insert("common.rob".into(), Testbench {
        name: "common.rob".into(),
        filelist: PathBuf::from("sim/common/rob/filelist.f"),
        run_template: "$bin $plusargs +TIMEOUT=10000".into(),
        sw_deps: vec![],
        ..Default::default()
    });

    // config.testbenches.insert("rv_pa3.cosim".into(), Testbench {
    //     name: "rv_pa3.cosim".into(),
    //     filelist: PathBuf::from("sim/rv_pa3/cosim/filelist.f"),
    // });

    config.param_sets.insert("base".into(), ParamSet {
        name: "base".into(),
        defines: BTreeMap::from([("UNIFIED".into(), "0".into())]),
        plusargs: vec![],
        sim_templates: HashMap::new(),
    });

    config.param_sets.insert("unified".into(), ParamSet {
        name: "unified".into(),
        defines: BTreeMap::from([("UNIFIED".into(), "1".into())]),
        plusargs: vec![],
        sim_templates: HashMap::new(),
    });

    config.experiments.push(Experiment {
        name: "regression".into(),
        testbench: "rv_pa3.anyrom".into(),
        param_sets: vec!["base".into(), "unified".into()],
        suites: vec!["isa".into()],
        simulators: vec!["verilator".into()],
    });

    config.experiments.push(Experiment {
        name: "regression2".into(),
        testbench: "rv_pa3.anyrom".into(),
        param_sets: vec!["unified".into()],
        suites: vec!["isa".into()],
        simulators: vec!["verilator".into()],
    });

    config.experiments.push(Experiment {
        name: "rob".into(),
        testbench: "common.rob".into(),
        param_sets: vec!["base".into()],
        suites: vec![],
        simulators: vec!["verilator".into()],
    });

    Ok((config, silo::SiloResolver::new("build_test".into())))
}

