use clap::{Args, Parser, Subcommand, ValueHint};
use clap_complete::Shell;
use std::path::PathBuf;

#[derive(Parser)]
#[command(
    name = "harness",
    about = "PA Orchestrator - Hardware/Software Build System",
    version,
    propagate_version = true
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,

    /// Print verbose debug information
    #[arg(short, long, global = true)]
    pub verbose: bool,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Generate the build.ninja file and exit
    Gen,
    /// List all available hardware configurations and tests
    List,
    /// Compile hardware binaries only
    Compile(ActionArgs),
    /// Run simulations (and hardware compilation if needed)
    Simulate(ActionArgs),
    /// Remove build directory and generated files
    Clean,
    /// Generate shell completion scripts for bash, zsh, etc.
    Completions {
        #[arg(value_enum)]
        shell: Shell,
    },
}

#[derive(Args)]
pub struct ActionArgs {
    /// Filter by test name or path (substring match)
    #[arg(short, long)]
    pub test: Option<String>,

    /// Filter by hardware processor or variant name
    #[arg(long)]
    pub hw: Option<String>,

    /// Filter by simulator name (verilator, vsim, etc.)
    #[arg(short, long)]
    pub sim: Option<String>,
}
