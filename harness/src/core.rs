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
pub struct Task {
    pub namespace: String,
    pub name: String,
    pub command: String,
    pub inputs: Vec<PathBuf>,
    pub outputs: Vec<PathBuf>,
    pub vars: HashMap<String, String>,
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
    pub sw_deps: Vec<PathBuf>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Testbench {
    pub name: String,
    pub filelist: PathBuf,
    pub run_template: String, 
    #[serde(default)]
    pub sw_deps: Vec<PathBuf>,
    #[serde(default)]
    pub vars: HashMap<String, String>, // For $(VAR) substitution
}

impl Default for Testbench {
    fn default() -> Self {
        Self {
            name: String::new(),
            filelist: PathBuf::new(),
            run_template: String::new(),
            sw_deps: Vec::new(),
            vars: HashMap::new(),
        }
    }
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
    // pub proj_dir: String,
    pub tools: HashMap<String, Tool>,
    pub simulators: HashMap<String, Simulator>,
    pub suites: HashMap<String, Suite>,
    pub testbenches: HashMap<String, Testbench>,
    pub param_sets: HashMap<String, ParamSet>,
    pub experiments: Vec<Experiment>,
    pub tasks: Vec<Task>,
    pub hooks: HookRegistry,
}

impl Config {
    pub fn new() -> Self {
        Self {
            build_dir: "build".into(),
            tools: HashMap::new(),
            simulators: HashMap::new(),
            suites: HashMap::new(),
            testbenches: HashMap::new(),
            param_sets: HashMap::new(),
            experiments: Vec::new(),
            tasks: Vec::new(),
            hooks: HookRegistry::new(),
        }
    }
}

#[derive(Debug, Hash, PartialEq, Eq, Clone, Copy)]
pub enum TestbenchHook {
    PreCompile,
    PostCompile,
}

#[derive(Debug, Hash, PartialEq, Eq, Clone, Copy)]
pub enum SuiteHook {
    PreBuild,
    PostBuild,
}

#[derive(Debug, Hash, PartialEq, Eq, Clone, Copy)]
pub enum ExperimentHook {
    PreSimulate,
    PostSimulate,
}

use std::sync::Arc;

#[derive(Clone, Debug)]
pub struct HookRegistry {
    pub testbench: HashMap<(String, TestbenchHook), Arc<mlua::RegistryKey>>,
    pub suite: HashMap<(String, SuiteHook), Arc<mlua::RegistryKey>>,
    pub experiment: HashMap<(String, ExperimentHook), Arc<mlua::RegistryKey>>,
}

impl HookRegistry {
    pub fn new() -> Self {
        Self {
            testbench: HashMap::new(),
            suite: HashMap::new(),
            experiment: HashMap::new(),
        }
    }
}
