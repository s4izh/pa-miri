use std::collections::{BTreeMap, HashMap};
use std::path::PathBuf;

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum ArtifactKind {
    Elf,
    Object,
    Map,
    MemoryHexIns,  // Instruction ROM
    MemoryHexData, // SRAM/Data
    MemoryHexFull,
    Executable,    // Compiled HW simulation binary
    Waveform,      // FST/VCD
    Log,           // sim.log
}

#[derive(Clone, Debug)]
pub struct Artifact {
    pub name: String,        // Logical name used in templates (e.g., "rom")
    pub filename: String,    // Physical filename in silo (e.g., "rom.hex")
    pub kind: ArtifactKind,
}

#[derive(Clone, Debug)]
pub struct Action {
    pub name: String,
    pub command: String,       // Template: "gcc $flags -c $in -o $out"
    pub inputs: Vec<String>,   // Logical names of artifacts consumed (e.g., ["obj"])
    pub outputs: Vec<Artifact>, // Artifacts produced by this action
}

#[derive(Clone, Debug)]
pub struct Tool {
    pub name: String,
    pub actions: Vec<Action>,
}

#[derive(Clone, Debug)]
pub struct Simulator {
    pub name: String,
    pub compile_rule: String,
    pub outputs: Vec<Artifact>,   // What the HW compiler produces (e.g., "bin" -> "Vtop")
    pub default_run_rule: String, // Template: "$bin $plusargs +ROM=$rom"
}

#[derive(Clone, Debug)]
pub struct Variant {
    pub params: BTreeMap<String, String>,
    pub plusargs: Vec<String>,
    pub sim_templates: HashMap<String, String>, // Override run template per simulator
}

#[derive(Clone, Debug)]
pub struct Processor {
    pub name: String,
    pub rtl_filelist: PathBuf,
    pub base_params: BTreeMap<String, String>,
    pub variants: HashMap<String, Variant>,
    pub plusargs: Vec<String>,
    pub sim_templates: HashMap<String, String>, // sim_name -> template
}

#[derive(Clone, Debug)]
pub struct ProgramOverride {
    pub vars: HashMap<String, String>,
    pub plusargs: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct Suite {
    pub name: String,
    pub base_dir: PathBuf,
    pub pattern: String,
    pub tool: String, // Key in Config.tools
    pub default_vars: HashMap<String, String>,
    pub plusargs: Vec<String>,
    pub program_overrides: HashMap<String, ProgramOverride>,
}

#[derive(Clone, Debug)]
pub struct Testbench {
    pub name: String,
    pub filelist: PathBuf,
}

#[derive(Clone, Debug)]
pub struct Binding {
    pub name: String,
    pub processors: Vec<String>,
    pub variants: Vec<String>,
    pub suites: Vec<String>,
    pub testbenches: Vec<String>,
    pub simulators: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct StandaloneBinding {
    pub name: String,
    pub filelist: PathBuf,
    pub simulator: String,
    pub plusargs: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct Config {
    pub processors: HashMap<String, Processor>,
    pub tools: HashMap<String, Tool>,
    pub simulators: HashMap<String, Simulator>,
    pub suites: HashMap<String, Suite>,
    pub testbenches: HashMap<String, Testbench>,
    pub bindings: Vec<Binding>,
    pub standalone_bindings: Vec<StandaloneBinding>,
}

impl Config {
    pub fn new() -> Self {
        Self {
            processors: HashMap::new(),
            tools: HashMap::new(),
            simulators: HashMap::new(),
            suites: HashMap::new(),
            testbenches: HashMap::new(),
            bindings: Vec::new(),
            standalone_bindings: Vec::new(),
        }
    }
}
