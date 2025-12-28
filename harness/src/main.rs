mod core;
mod sw;
mod ninja;
mod silo;
mod hw;
mod sim;
mod cli;
mod analysis;
mod discovery;

use crate::core::*;
use std::collections::{HashMap,BTreeMap};

use clap::{CommandFactory, Parser};
use std::path::{Path, PathBuf};
use std::process::Command;
use regex::Regex;

use crate::cli::{Cli, Commands, ActionArgs};
use crate::core::Config;

fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    let proj_root: PathBuf = std::env::var("PROJ_DIR")?.into();

    let (config, silo) = setup_config(&proj_root)?;

    match &cli.command {
        Commands::Gen => {
            println!("Discovering targets...");
            let (all_hw, all_sw, all_sim) = resolve_all_jobs(&config, &silo)?;
            
            let ninja_str = ninja::generate(&config, &all_hw, &all_sw, &all_sim);
            let ninja_path = proj_root.join("build.ninja");
            
            std::fs::write(&ninja_path, ninja_str)?;
            println!("Ninja file generated at: {}", ninja_path.display());
            println!("   Total HW targets:  {}", all_hw.len());
            println!("   Total SW targets:  {}", all_sw.len());
            println!("   Total Sim targets: {}", all_sim.len());
        }
        cli::Commands::Completions { shell } => {
            let mut cmd = cli::Cli::command();
            let name = cmd.get_name().to_string();
            clap_complete::generate(*shell, &mut cmd, name, &mut std::io::stdout());
        }
        cli::Commands::List => {
            let (all_hw, all_sw, _) = resolve_all_jobs(&config, &silo)?;
            println!("\n--- Hardware Configurations ---");
            for h in all_hw {
                println!("  - {:<15} (Variant: {:<10}, Sim: {})", h.processor, h.variant, h.simulator);
            }
            println!("\n--- Software Suites ---");
            for s in all_sw {
                println!("  - Suite: {:<10} Program: {}", s.suite_name, s.rel_path.display());
            }
        }

        cli::Commands::Clean => {
            let build_dir = proj_root.join(&silo.root);
            if build_dir.exists() {
                std::fs::remove_dir_all(&build_dir)?;
                println!("Cleaned {}", build_dir.display());
            }
            let _ = std::fs::remove_file(proj_root.join("build.ninja"));
        }

        cli::Commands::Compile(args) | cli::Commands::Simulate(args) => {
            let (all_hw, all_sw, all_sim) = resolve_all_jobs(&config, &silo)?;
            
            let ninja_str = ninja::generate(&config, &all_hw, &all_sw, &all_sim);
            std::fs::write(proj_root.join("build.ninja"), ninja_str)?;

            let test_re = Regex::new(args.test.as_deref().unwrap_or(".*"))
                .map_err(|e| anyhow::anyhow!("Invalid Test Regex: {}", e))?;
            let hw_re = Regex::new(args.hw.as_deref().unwrap_or(".*"))
                .map_err(|e| anyhow::anyhow!("Invalid HW Regex: {}", e))?;
            let sim_re = Regex::new(args.sim.as_deref().unwrap_or(".*"))
                .map_err(|e| anyhow::anyhow!("Invalid Sim Regex: {}", e))?;

            let mut targets = Vec::new();

            if matches!(cli.command, Commands::Simulate(_)) {
                for s in all_sim {
                    let path_str = s.silo_dir.to_string_lossy();
                    
                    if hw_re.is_match(&path_str) && 
                       test_re.is_match(&path_str) && 
                       sim_re.is_match(&path_str) 
                    {
                        targets.push(s.silo_dir.join("sim.log").to_string_lossy().to_string());
                    }
                }
            } else {
                for h in all_hw {
                    if hw_re.is_match(&h.processor) && sim_re.is_match(&h.simulator) {
                         for path in h.artifact_paths.values() {
                            targets.push(path.to_string_lossy().to_string());
                        }
                    }
                }
            }

            // let targets = if matches!(cli.command, cli::Commands::Compile(_)) {
            //     all_hw.iter()
            //         .filter(|h| {
            //             args.hw.as_ref().map_or(true, |f| h.processor.contains(f)) &&
            //             args.sim.as_ref().map_or(true, |f| h.simulator.contains(f))
            //         })
            //         .flat_map(|h| h.artifact_paths.values())
            //         .map(|p| p.to_string_lossy().to_string())
            //         .collect::<Vec<_>>()
            // } else {
            //     all_sim.iter()
            //         .filter(|s| {
            //             let path = s.silo_dir.to_string_lossy();
            //             args.hw.as_ref().map_or(true, |f| path.contains(f)) &&
            //             args.sim.as_ref().map_or(true, |f| path.contains(f)) &&
            //             args.test.as_ref().map_or(true, |f| path.contains(f))
            //         })
            //         .map(|s| s.silo_dir.join("sim.log").to_string_lossy().to_string())
            //         .collect::<Vec<_>>()
            // };

            if targets.is_empty() {
                println!("No targets matched your filter.");
            } else {
                println!("Launching Ninja for {} target(s)...", targets.len());
                let ninja_ok = run_ninja(&proj_root, &targets).is_ok();
                
                if matches!(cli.command, cli::Commands::Simulate(_)) {
                    analysis::run_analysis(&proj_root, &targets)?;
                }

                if !ninja_ok {
                    std::process::exit(1);
                }
            }
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

fn run_ninja(root: &Path, targets: &[String]) -> anyhow::Result<()> {
    let status = Command::new("ninja")
        .current_dir(root)
        .args(targets)
        .status()?;
    if !status.success() {
        anyhow::bail!("Ninja failed to complete build.");
    }
    Ok(())
}

fn filter_hardware_targets(jobs: &[hw::HardwareJob], args: &ActionArgs) -> Vec<String> {
    jobs.iter()
        .filter(|j| args.hw.as_ref().map_or(true, |f| j.processor.contains(f) || j.variant.contains(f)))
        .filter(|j| args.sim.as_ref().map_or(true, |f| j.simulator.contains(f)))
        .flat_map(|j| j.artifact_paths.values())
        .map(|p| p.to_string_lossy().to_string())
        .collect()
}

fn filter_simulation_targets(jobs: &[sim::SimJob], args: &ActionArgs) -> Vec<String> {
    jobs.iter()
        .filter(|j| {
            let path = j.silo_dir.to_string_lossy();
            let hw_ok = args.hw.as_ref().map_or(true, |f| path.contains(f));
            let sim_ok = args.sim.as_ref().map_or(true, |f| path.contains(f));
            let test_ok = args.test.as_ref().map_or(true, |f| path.contains(f));
            hw_ok && sim_ok && test_ok
        })
        .map(|j| j.silo_dir.join("sim.log").to_string_lossy().to_string())
        .collect()
}

fn resolve_all_jobs(config: &Config, silo: &silo::SiloResolver) 
    -> anyhow::Result<(Vec<hw::HardwareJob>, Vec<sw::SoftwareJob>, Vec<sim::SimJob>)> 
{
    let mut all_hw = Vec::new();
    let mut all_sw = Vec::new();
    let mut all_sim = Vec::new();

    let unit_hw = hw::resolve_standalone_hw(config, silo)?;
    let unit_sim = sim::resolve_standalone_sims(&unit_hw, config)?;

    all_hw.extend(unit_hw);
    all_sim.extend(unit_sim);

    for bind in &config.bindings {
        let hw_jobs = hw::resolve_hardware(config, bind, silo)?;
        let mut sw_jobs = Vec::new();
        for suite in &bind.suites {
            sw_jobs.extend(sw::resolve_suite(config, suite, silo)?);
        }
        let sim_jobs = sim::resolve_simulations(config, bind, &hw_jobs, &sw_jobs, silo)?;

        all_hw.extend(hw_jobs);
        all_sw.extend(sw_jobs);
        all_sim.extend(sim_jobs);
    }

    Ok((all_hw, all_sw, all_sim))
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
                    name: "obj".into(), filename: "prog.o".into(), kind: ArtifactKind::Object
                }],
            },
            Action {
                name: "link".into(),
                command: "riscv32-none-elf-gcc $flags -T $ld -nostdlib -Wl,-Map,$map $obj -o $elf".into(),
                inputs: vec!["obj".into()],
                outputs: vec![
                    Artifact { name: "elf".into(), filename: "prog.elf".into(), kind: ArtifactKind::Elf },
                    Artifact { name: "map".into(), filename: "prog.map".into(), kind: ArtifactKind::Map }
                ],
            },
            Action {
                name: "rom".into(),
                command: "riscv32-none-elf-objcopy -O verilog --verilog-data-width 4 --only-section=.text* $elf $out_dir/rom.tmp && \
                    cat $out_dir/rom.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $rom && \
                    rm $out_dir/rom.tmp".into(),
                inputs: vec!["elf".into()],
                outputs: vec![ Artifact { name: "rom".into(), filename: "rom.hex".into(), kind: ArtifactKind::MemoryHexIns } ],
            },
            Action {
                name: "sram".into(),
                command: "riscv32-none-elf-objcopy -O verilog --verilog-data-width 4 --only-section=.data* --only-section=.sdata* --only-section=.bss* --only-section=.sbss* $elf $out_dir/sram.tmp && \
                    cat $out_dir/sram.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $sram && \
                    rm $out_dir/sram.tmp".into(),
                inputs: vec!["elf".into()],
                outputs: vec![ Artifact { name: "sram".into(), filename: "sram.hex".into(), kind: ArtifactKind::MemoryHexData } ],
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
    });

    config.simulators.insert("verilator".into(), Simulator {
        name: "verilator".into(),
        compile_rule: "verilator -j 8 --cc --binary --build -O3 --trace-fst --trace-structs --timing -f $filelist --top-module top_tb_wrapper --Mdir $out_dir -o Vtop".into(),
        outputs: vec![Artifact { name: "bin".into(), filename: "Vtop".into(), kind: ArtifactKind::Executable }],
        default_run_rule: "$bin $plusargs".into(),
    });

    let mut rv_pa3 = Processor {
        name: "rv_pa3".into(),
        rtl_filelist: PathBuf::from("rtl/rv_pa3/rv_pa3.f"),
        base_params: BTreeMap::new(),
        variants: HashMap::new(),
        plusargs: vec![],
        sim_templates: HashMap::from([
            ("verilator".into(), "$bin $plusargs +VCD_FILE=waves.fst +ROM_FILE=$rom +SRAM_FILE=$sram".into())
        ]),
    };

    rv_pa3.variants.insert("base".into(), Variant {
        params: BTreeMap::from([("UNIFIED".into(), "0".into())]),
        plusargs: vec![],
        sim_templates: HashMap::new(), // Inherits "+ROM_FILE=$rom +SRAM_FILE=$sram"
    });

    rv_pa3.variants.insert("unified".into(), Variant {
        params: BTreeMap::from([("UNIFIED".into(), "1".into())]),
        plusargs: vec![],
        sim_templates: HashMap::new(), // Inherits "+ROM_FILE=$rom +SRAM_FILE=$sram"
    });

    // rv_pa3.variants.insert("unified_mem".into(), Variant {
    //     params: BTreeMap::from([("UNIFIED".into(), "1".into())]),
    //     plusargs: vec![],
    //     sim_templates: HashMap::from([
    //         ("verilator".into(), "$bin $plusargs +UNIFIED_IMG=$rom".into())
    //     ]),
    // });

    config.testbenches.insert("anyrom".into(), Testbench {
        name: "anyrom".into(),
        filelist: PathBuf::from("sim/rv_pa3/anyrom/filelist.f"),
    });

    config.testbenches.insert("cosim".into(), Testbench {
        name: "cosim".into(),
        filelist: PathBuf::from("sim/rv_pa3/cosim/filelist.f"),
    });

    config.bindings.push(Binding {
        name: "regression".into(),
        processors: vec!["rv_pa3".into()],
        variants: vec!["base".into(), "unified".into()],
        suites: vec!["isa".into()],
        testbenches: vec!["anyrom".into(), "cosim".into()],
        simulators: vec!["verilator".into()],
    });

    config.processors.insert("rv_pa3".into(), rv_pa3);

    // config.standalone_bindings.push(StandaloneBinding {
    //     name: "rob".into(),
    //     filelist: root.join("sim/common/rob/filelist.f"),
    //     simulator: "verilator".into(),
    //     plusargs: vec!["+TIMEOUT=5000".into()],
    // });

    // config.standalone_bindings = discovery::discover_unit_tests(root);

    Ok((config, silo::SiloResolver::new("build_test".into())))
}

