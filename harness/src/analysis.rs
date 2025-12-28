use std::fs;
use std::path::{Path, PathBuf};
use regex::Regex;
use colored::*;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct SimMetrics {
    pub hw_id: String,      // proc/variant/tb
    pub program: String,    // suite/prog
    pub cycles: u64,
    pub instructions: u64,
    pub result_code: u64,
    pub cpi: f64,
}

pub fn run_analysis(root: &Path, log_targets: &[String]) -> anyhow::Result<()> {
    if log_targets.is_empty() { return Ok(()); }

    // TESTBENCH_RESULTS: res=0, clk=1250, ins=800
    let re = Regex::new(r"TESTBENCH_RESULTS:\s*res=(\d+),\s*clk=(\d+),\s*ins=(\d+)")?;
    let mut all_results = Vec::new();

    for log_path_str in log_targets {
        let full_path = root.join(log_path_str);
        if !full_path.exists() { continue; }

        let content = fs::read_to_string(&full_path)?;
        
        if let Some(cap) = re.captures(&content) {
            let res: u64 = cap[1].parse().unwrap_or(0);
            let clk: u64 = cap[2].parse().unwrap_or(0);
            let ins: u64 = cap[3].parse().unwrap_or(0);
            let cpi = if ins > 0 { clk as f64 / ins as f64 } else { 0.0 };

            // extract context from path
            let path_obj = PathBuf::from(log_path_str);
            let comps: Vec<_> = path_obj.components()
                .map(|c| c.as_os_str().to_string_lossy().to_string())
                .collect();

            if comps.len() >= 8 {
                all_results.push(SimMetrics {
                    hw_id: format!("{}/{}", comps[3], comps[4]), // proc_var/tb
                    program: comps[6..comps.len()-1].join("/"),
                    cycles: clk,
                    instructions: ins,
                    result_code: res,
                    cpi,
                });
            }
        }
    }

    print_metrics_table(&all_results);
    print_comparison_table(&all_results);

    Ok(())
}

fn print_metrics_table(results: &[SimMetrics]) {
    println!("\n{}", "      DETAILED EXECUTION METRICS      ".on_blue().white().bold());
    println!("{:<30} {:<30} {:<10} {:<10} {:<6} {:<6}", "PROGRAM", "HARDWARE", "CYCLES", "INSTR", "CPI", "RES");
    println!("{}", "-".repeat(100));

    for r in results {
        let status_color = if r.result_code == 0 { "OK".green() } else { "ERR".red() };
        println!("{:<30} {:<30} {:<10} {:<10} {:<6.2} {:<6}", 
            r.program, r.hw_id, r.cycles, r.instructions, r.cpi, status_color);
    }
}

fn print_comparison_table(results: &[SimMetrics]) {
    // group results by program: ProgramName -> List of (HwId, Cycles)
    let mut comparison: HashMap<String, Vec<(String, u64)>> = HashMap::new();
    for r in results {
        comparison.entry(r.program.clone()).or_default().push((r.hw_id.clone(), r.cycles));
    }

    println!("\n{}", "      PROCESSOR SPEEDUP ANALYSIS      ".on_purple().white().bold());
    println!("{:<30} {:<30} {:<15} {:<10}", "PROGRAM", "HARDWARE", "CYCLES", "SPEEDUP");
    println!("{}", "-".repeat(90));

    for (prog, runs) in comparison {
        if runs.len() < 2 { continue; } // only compare if program ran on >1 HW

        // assume the first hardware found is the baseline, TODO: improve??
        let (baseline_hw, baseline_cycles) = runs[0].clone();
        
        for (hw, cyc) in runs {
            let speedup = baseline_cycles as f64 / cyc as f64;
            let speedup_str = if speedup > 1.05 {
                format!("{:.2}x", speedup).green().bold().to_string()
            } else if speedup < 0.95 {
                format!("{:.2}x", speedup).red().to_string()
            } else {
                format!("{:.2}x", speedup).white().to_string()
            };

            let note = if hw == baseline_hw { "(baseline)" } else { "" };
            println!("{:<30} {:<30} {:<15} {:<10} {}", 
                prog, hw, cyc, speedup_str, note.dimmed());
        }
        println!("{}", ".".repeat(90).dimmed());
    }
}
