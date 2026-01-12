use clap::{Args, Parser, Subcommand};
use clap_complete::Shell;

#[derive(Parser)]
#[command(name = "harness", about = "PA Orchestrator", version)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,

    #[arg(short, long, global = true)]
    pub verbose: bool,
}

#[derive(Subcommand)]
pub enum Commands {
    Gen,
    List,
    /// Compile, Simulate, and Analyze an experiment
    Simulate(ExperimentArgs),
    /// Compile hardware and software for an experiment
    Compile(ExperimentArgs),
    /// Analyze logs for an experiment
    Analyze(ExperimentArgs),
    /// Remove build artifacts
    Clean(CleanArgs),
    Completions { shell: Shell },
}

#[derive(Args)]
pub struct ExperimentArgs {
    /// Positional: Experiment name (Exact match)
    pub experiment: Option<String>,

    /// Filter: Regex match for software paths/suites
    #[arg(long)]
    pub sw: Option<String>,

    /// Filter: Exact match for ParamSet name
    #[arg(long)]
    pub hw: Option<String>,

    /// Filter: Exact match for Simulator name
    #[arg(short, long)]
    pub sim: Option<String>,

    /// Baseline Hardware (ParamSet name) for speedup comparison
    #[arg(long)]
    pub baseline: Option<String>,

    /// Number of parallel jobs
    #[arg(short = 'j', long)]
    pub jobs: Option<usize>,
}

#[derive(Args)]
pub struct CleanArgs {
    /// Optional: Specific experiment to clean (Exact match)
    pub experiment: Option<String>,

    /// Filter: Regex match for software suites
    #[arg(long)]
    pub sw: Option<String>,

    /// Filter: Exact match for ParamSet name
    #[arg(long)]
    pub hw: Option<String>,

    /// Filter: Exact match for Simulator name
    #[arg(short, long)]
    pub sim: Option<String>,
}
