use std::fs;
use std::path::{Path, PathBuf};
use regex::Regex;
use colored::*;
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct SimMetrics {
    pub experiment: String,
    pub hw_id: String,
    pub program: String,
    pub cycles: u64,
    pub instructions: u64,
    pub result_code: u64,
    pub cpi: f64,
    pub status: SimStatus,
    pub log_path: PathBuf,
    pub wave_path: PathBuf,
    pub is_standalone: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub enum SimStatus {
    Pass,
    Fail,
    Timeout,
    Crash, // Log exists but results line missing
}

pub fn run_analysis(root: &Path, log_targets: &[String], baseline: Option<&str>) -> anyhow::Result<()> {
    if log_targets.is_empty() { return Ok(()); }

    let re = Regex::new(r"TESTBENCH_RESULTS:\s*res=(\d+),\s*clk=(\d+),\s*ins=(\d+)")?;
    let mut all_results = Vec::new();

    for log_path_str in log_targets {
        let full_path = root.join(log_path_str);
        if !full_path.exists() { continue; }

        let content = fs::read_to_string(&full_path)?;
        let path_obj = PathBuf::from(log_path_str);
        let comps: Vec<_> = path_obj.components().map(|c| c.as_os_str().to_string_lossy().to_string()).collect();

        if comps.len() < 8 { continue; }

        let log_dir = path_obj.parent().unwrap();

        let wave_path = ["waves.fst", "waves.vcd"]
            .iter()
            .map(|ext| log_dir.join(ext))
            .find(|p| root.join(p).exists())
            .unwrap_or_else(|| log_dir.join("waves.fst"));

        let is_standalone = log_path_str.contains("/standalone/");

        let mut metrics = SimMetrics {
            experiment: comps[2].clone(),
            hw_id: format!("{}/{}", comps[3], comps[4]),
            program: comps[6..comps.len()-1].join("/"),
            cycles: 0, instructions: 0, result_code: 1, cpi: 0.0,
            status: SimStatus::Crash,
            log_path: path_obj.clone(),
            wave_path,
            is_standalone
        };

        if let Some(cap) = re.captures(&content) {
            metrics.result_code = cap[1].parse().unwrap_or(1);
            metrics.cycles = cap[2].parse().unwrap_or(0);
            metrics.instructions = cap[3].parse().unwrap_or(0);
            metrics.status = match metrics.result_code {
                0 => SimStatus::Pass,
                1 => SimStatus::Fail,
                2 => SimStatus::Timeout,
                _ => SimStatus::Crash,
            };
            if metrics.instructions > 0 { metrics.cpi = metrics.cycles as f64 / metrics.instructions as f64; }
        }
        all_results.push(metrics);
    }

    let mut experiment_groups: HashMap<String, Vec<SimMetrics>> = HashMap::new();
    for r in all_results { experiment_groups.entry(r.experiment.clone()).or_default().push(r); }

    // for (exp_name, results) in experiment_groups {
    //     println!("\n{}", format!(" EXPERIMENT: {} ", exp_name).on_yellow().black().bold());
    //     print_metrics_table(&results);
    //     print_comparison_table(&results, baseline);
    //     print_failure_report(&results, root);
    // }

    for (exp_name, results) in experiment_groups {
        println!("\n{}", format!(" EXPERIMENT: {} ", exp_name).on_yellow().black().bold());
        
        let (standalone, software): (Vec<_>, Vec<_>) = results.clone().into_iter().partition(|r| r.is_standalone);

        if !standalone.is_empty() {
            print_standalone_report(&standalone, root);
        }

        if !software.is_empty() {
            let has_failures = results.iter().any(|r| r.status != SimStatus::Pass);
            if has_failures {
                print_failure_report(&results, root);
            }
            print_comparison_table(&software, baseline);
            print_metrics_table(&software);
            if !has_failures {
                println!("\n{}", "ALL TESTS PASSED!".green().bold());
            }
        }
    }

    Ok(())
}

fn print_standalone_report(results: &[SimMetrics], root: &Path) {
    for r in results {
        // let status_tag = match r.status {
        //     SimStatus::Pass => " [PASS] ".on_green().white().bold(),
        //     SimStatus::Fail => " [FAIL] ".on_red().white().bold(),
        //     SimStatus::Crash => " [CRASH] ".on_red().black().bold(),
        // };

        // println!("\n{} Test: {}", status_tag, r.program.bold());
        println!("\nTest: {}", r.program.bold());
        println!("  - Log:  {}", root.join(&r.log_path).display().to_string().dimmed());
        println!("  - Wave: {}", root.join(&r.wave_path).display().to_string().cyan());
    }
}

fn print_metrics_table(results: &[SimMetrics]) {
    println!("\n{}", "            TESTS RESULTS             ".on_blue().black().bold());
    println!("{:<40} {:<30} {:<10} {:<10} {:<6} {:<6}", "PROGRAM", "HARDWARE", "CYCLES", "INSTR", "CPI", "STATUS");
    println!("{}", "-".repeat(110));

    for r in results {
        let status_str = match r.status {
            SimStatus::Pass => "PASS".green(),
            SimStatus::Fail => "FAIL".red(),
            SimStatus::Timeout => "TIMEOUT".yellow(),
            SimStatus::Crash => "CRASH".on_red().white(),
        };
        println!("{:<40} {:<30} {:<10} {:<10} {:<6.2} {:<6}", 
            r.program, r.hw_id, r.cycles, r.instructions, r.cpi, status_str);
    }
}

fn print_failure_report(results: &[SimMetrics], root: &Path) {
    let failures: Vec<_> = results.iter().filter(|r| r.status != SimStatus::Pass).collect();
    if failures.is_empty() { return; }

    println!("\n{}", "      FAILURE DEBUG INFO      ".on_red().white().bold());
    for f in failures {
        println!("{}: {}", "Test".bold(), format!("{}/{}", f.program, f.hw_id).red());
        println!("  - Log:  {}", root.join(&f.log_path).display().to_string().dimmed());
        println!("  - Wave: {}", root.join(&f.wave_path).display().to_string().cyan());
        println!();
    }
}

fn print_comparison_table(results: &[SimMetrics], baseline_hw_name: Option<&str>) {
    // group results by program: ProgramName -> List of (HwId, Cycles)
    let mut comparison: HashMap<String, Vec<(String, u64)>> = HashMap::new();
    for r in results {
        comparison.entry(r.program.clone()).or_default().push((r.hw_id.clone(), r.cycles));
    }

    println!("\n{}", "      PROCESSOR SPEEDUP ANALYSIS      ".on_purple().black().bold());
    println!("{:<30} {:<30} {:<15} {:<10}", "PROGRAM", "HARDWARE", "CYCLES", "SPEEDUP");
    println!("{}", "-".repeat(90));

    let mut progs: Vec<_> = comparison.keys().collect();
    progs.sort();

    for prog in progs {
        let runs = &comparison[prog];
        if runs.len() < 2 && baseline_hw_name.is_none() { continue; } 

        let (baseline_hw, baseline_cycles) = if let Some(target) = baseline_hw_name {
            // try to find a run where the hw_id contains the baseline string
            runs.iter()
                .find(|(hw, _)| hw.contains(target) || hw.split('/').last() == Some(target))
                .cloned()
                .unwrap_or_else(|| runs[0].clone()) // fallback to first if not found
        } else {
            runs[0].clone() // default to first run
        };
        
        for (hw, cyc) in runs {
            let speedup = if *cyc > 0 && baseline_cycles > 0 { 
                baseline_cycles as f64 / *cyc as f64 
            } else { 
                1.0 
            };

            let speedup_str = if speedup > 1.05 {
                format!("{:.2}x", speedup).green().bold().to_string()
            } else if speedup < 0.95 {
                format!("{:.2}x", speedup).red().to_string()
            } else {
                format!("{:.2}x", speedup).white().to_string()
            };

            let is_baseline = *hw == baseline_hw;
            let note = if is_baseline { "(baseline)" } else { "" };
            
            println!("{:<30} {:<30} {:<15} {:<10} {}", 
                prog, hw, cyc, speedup_str, note.dimmed());
        }
        println!("{}", ".".repeat(90).dimmed());
    }
}
