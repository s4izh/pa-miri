use std::collections::{BTreeMap, HashMap};
use std::path::PathBuf;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Artifact {
    pub name: String,        // Logical name (e.g., "rom")
    pub filename: String,    // Physical name (e.g., "rom.hex")
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Action {
    pub name: String,
    pub command: String,       
    pub inputs: Vec<String>,   
    pub outputs: Vec<Artifact>, 
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Tool {
    pub name: String,
    pub actions: Vec<Action>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SharedJob {
    pub name: String,
    pub tool: String,
    pub inputs: Vec<PathBuf>,
    pub var_overrides: HashMap<String, String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Simulator {
    pub name: String,
    pub compile_rule: String,
    pub outputs: Vec<Artifact>,   
    pub default_run_rule: String, 
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ProgramOverride {
    pub vars: HashMap<String, String>,
    pub plusargs: Vec<String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Suite {
    pub name: String,
    pub base_dir: PathBuf,
    pub pattern: String,
    pub tool: String, 
    pub default_vars: HashMap<String, String>,
    pub plusargs: Vec<String>,
    #[serde(default)]
    pub program_overrides: HashMap<String, ProgramOverride>,
    #[serde(default)]
    pub sw_deps: Vec<String>, // SharedJobs this suite links against
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Testbench {
    pub name: String,
    pub filelist: PathBuf,
    pub run_template: String, 
    pub sw_deps: Vec<String>, // SharedJobs this HW links against (e.g. cosim.a)
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ParamSet {
    pub name: String,
    pub defines: BTreeMap<String, String>,
    #[serde(default)]
    pub plusargs: Vec<String>,
    #[serde(default)]
    pub sim_templates: HashMap<String, String>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Experiment {
    pub name: String,
    pub testbench: String,       
    pub param_sets: Vec<String>, 
    pub suites: Vec<String>,     
    pub simulators: Vec<String>, 
}

#[derive(Clone, Debug)]
pub struct Config {
    pub build_dir: String,
    pub tools: HashMap<String, Tool>,
    pub shared_jobs: HashMap<String, SharedJob>,
    pub simulators: HashMap<String, Simulator>,
    pub suites: HashMap<String, Suite>,
    pub testbenches: HashMap<String, Testbench>,
    pub param_sets: HashMap<String, ParamSet>,
    pub experiments: Vec<Experiment>,
}

impl Config {
    pub fn new() -> Self {
        Self {
            build_dir: "build".into(),
            tools: HashMap::new(),
            shared_jobs: HashMap::new(),
            simulators: HashMap::new(),
            suites: HashMap::new(),
            testbenches: HashMap::new(),
            param_sets: HashMap::new(),
            experiments: Vec::new(),
        }
    }
}
