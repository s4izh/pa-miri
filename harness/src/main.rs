mod core;
mod ninja;
mod silo;

use crate::core::*;
use anyhow::Context;
use std::collections::{BTreeMap, HashMap};
use std::fs;

const RESET: &str = "\x1b[0m";
const BOLD: &str = "\x1b[1m";
const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
const DIM: &str = "\x1b[2m";

fn main() -> anyhow::Result<()> {
    let verilator = Simulator {
        name: "verilator".into(),
        compile_rule: "verilator --cc --binary --build -O3 --trace-fst --trace-structs --timing -j $$(nproc) -f $filelist --top-module $top_module --Mdir $out_dir -o Vtop".into(),
        run_rule: "./Vtop".into(),
        param_prefix: "-G".into(),
    };

    let gcc = Builder {
        name: "riscv_gcc".into(),
        actions: vec![
            Action {
                name: "compile".into(),
                command: "riscv32-none-elf-gcc $flags -Iprograms -c $in -o $out_dir/prog.o".into(),
                inputs: vec![],
                outputs: vec!["prog.o".into()]
            },
            Action {
                name: "link".into(),
                command: "riscv32-none-elf-gcc $flags -T $ld -nostdlib -Wl,-Map,$out_dir/prog.map $in -o $out_dir/prog.elf".into(),
                inputs: vec!["prog.o".into()], outputs: vec!["prog.elf".into()]
            },
            Action {
                name: "rom".into(),
                command: "riscv32-none-elf-objcopy -O verilog --verilog-data-width 4 --only-section=.text* $out_dir/prog.elf $out_dir/rom.tmp && \
                    cat $out_dir/rom.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $out_dir/rom.hex && \
                    rm $out_dir/rom.tmp".into(),
                inputs: vec!["prog.elf".into()],
                outputs: vec!["rom.hex".into()]
            },
            Action {
                name: "sram".into(),
                command: "riscv32-none-elf-objcopy -O verilog --verilog-data-width 4 --only-section=.data* --only-section=.sdata* --only-section=.bss* --only-section=.sbss* $out_dir/prog.elf $out_dir/sram.tmp && \
                    cat $out_dir/sram.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $out_dir/sram.hex && \
                    rm $out_dir/sram.tmp".into(),
                inputs: vec!["prog.elf".into()],
                outputs: vec!["sram.hex".into()]
            },
        ],
    };

    let pa3 = Generator {
        name: "rv_pa3".into(),
        rtl_filelist: "rtl/rv_pa3/rv_pa3.f".into(),
        base_params: BTreeMap::from([("XLEN".into(), "32".into())]),
        variants: BTreeMap::from([
            (
                "base".into(),
                BTreeMap::from([("CACHE".into(), "0".into())]),
            ),
            (
                "cached".into(),
                BTreeMap::from([("CACHE".into(), "1".into()), ("SIZE".into(), "4096".into())]),
            ),
        ]),
    };

    let anyrom = Testbench {
        name: "cosim".into(),
        top_file: "sim/rv_pa3/cosim/filelist.f".into(),
        top_module: "top_tb_wrapper".into(),
    };

    let isa_suite = Suite {
        name: "isa".into(),
        base_dir: "programs/tohost_tests".into(),
        pattern: "**/*.s".into(),
        builder: gcc,
    };

    let mut jobs = vec![];
    let resolver = silo::SiloResolver::new();
    let pattern = isa_suite.base_dir.join(&isa_suite.pattern);
    let entries = glob::glob(pattern.to_str().unwrap())?;

    for entry in entries.flatten() {
        let rel_to_base = entry.strip_prefix(&isa_suite.base_dir)?;
        let prog_name = rel_to_base
            .file_stem()
            .unwrap()
            .to_str()
            .unwrap()
            .to_string();
        let rel_dir = rel_to_base.parent().unwrap().to_path_buf();

        let program = Program {
            name: prog_name,
            rel_dir,
            source: entry.clone(),
            suite_name: isa_suite.name.clone(),
        };

        for (v_name, v_params) in &pa3.variants {
            let mut final_params = pa3.base_params.clone();
            final_params.extend(v_params.clone());

            let mut vars = HashMap::new();
            vars.insert("flags".into(), "-march=rv32i -mabi=ilp32 -nostdlib".into());
            vars.insert("ld".into(), "programs/link.ld".into());

            let job = Job {
                generator: pa3.clone(),
                variant_name: v_name.clone(),
                tb: anyrom.clone(),
                sim: verilator.clone(),
                program: program.clone(),
                builder: isa_suite.builder.clone(),
                final_params,
                variables: vars,
            };

            let hw_dir = resolver.hw_dir(&job);
            fs::create_dir_all(&hw_dir)?;
            let mut vh = String::new();
            for (k, v) in &job.final_params {
                vh.push_str(&format!("`define {} {}\n", k, v));
            }
            fs::write(hw_dir.join("params.vh"), vh)?;
            let top_f = format!(
                "./params.vh\n-f {}\n",
                job.tb.top_file.canonicalize()?.display()
            );
            fs::write(hw_dir.join("top.f"), top_f)?;

            jobs.push(job);
        }
    }

    println!(
        "{BOLD}{GREEN}Forge Matrix Expanded: {} Jobs created.{RESET}",
        jobs.len()
    );
    let ninja_filename = "build2.ninja";
    let file_contents = ninja::generate(&jobs)?;
    fs::write(ninja_filename, file_contents)
        .with_context(|| format!("Failed to write to {}", ninja_filename))?;
    Ok(())
}
