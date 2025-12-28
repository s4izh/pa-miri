mod core;
mod sw;
mod ninja;
mod silo;
mod hw;
mod sim;

use crate::core::*;
use std::collections::{HashMap,BTreeMap};
use std::path::PathBuf;

fn setup_config() -> anyhow::Result<(Config, silo::SiloResolver)> {
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

    config.suites.insert("tohost_tests".into(), Suite {
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
            ("verilator".into(), "$bin $plusargs +ROM_FILE=$rom +SRAM_FILE=$sram".into())
        ]),
    };

    rv_pa3.variants.insert("base".into(), Variant {
        params: BTreeMap::from([("UNIFIED".into(), "0".into())]),
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
        filelist: PathBuf::from("tb/rv_pa3/tb_anyrom.f"),
    });

    config.suites.insert("isa".into(), Suite {
        name: "isa".into(),
        base_dir: PathBuf::from("programs/tohost_tests"),
        pattern: "**/*.s".into(),
        tool: "riscv_gcc".into(),
        default_vars: HashMap::from([
            ("flags".into(), "-march=rv32i -mabi=ilp32".into()),
            ("ld".into(), "programs/link.ld".into()),
        ]),
        plusargs: vec!["+TIMEOUT=20000".into()],
        program_overrides: HashMap::new(),
    });

    config.bindings.push(Binding {
        name: "smoke_regression".into(),
        processors: vec!["rv_pa3".into()],
        variants: vec!["base".into()],
        suites: vec!["isa".into()],
        testbenches: vec!["anyrom".into()],
        simulators: vec!["verilator".into()],
    });

    config.processors.insert("rv_pa3".into(), rv_pa3);

    Ok((config, silo::SiloResolver::new("build_test".into())))
}

fn main() -> anyhow::Result<()> {
    let mut all_hw = Vec::new();
    let mut all_sw = Vec::new();
    let mut all_sim = Vec::new();

    let (config, silo) = setup_config()?;

    for bind in &config.bindings {
        let hw = hw::resolve_hardware(&config, bind, &silo)?;
        let mut sw = Vec::new();
        for s_name in &bind.suites { sw.extend(sw::resolve_suite(&config, s_name, &silo)?); }
        let sim = sim::resolve_simulations(&config, bind, &hw, &sw, &silo)?;
        
        all_hw.extend(hw);
        all_sw.extend(sw);
        all_sim.extend(sim);
    }

    let ninja_str = ninja::generate(&config, &all_hw, &all_sw, &all_sim);

    std::fs::write("build.ninja", ninja_str).expect("Failed to write ninja file");
    println!("Software build graph generated in build.ninja");

    Ok(())
}
