use std::collections::BTreeMap;
use std::path::PathBuf;

#[derive(Clone, Debug)]
pub struct Simulator {
    pub name: String,
    pub compile_rule: String,
    pub run_rule: String,
    pub param_prefix: String,
}

#[derive(Clone, Debug)]
pub struct Generator {
    pub name: String,
    pub rtl_filelist: PathBuf,
    pub base_params: BTreeMap<String, String>,
    pub variants: BTreeMap<String, BTreeMap<String, String>>,
}

#[derive(Clone, Debug)]
pub struct Testbench {
    pub name: String,
    pub top_file: PathBuf,
    pub top_module: String,
}

#[derive(Clone, Debug)]
pub struct Action {
    pub name: String,
    pub command: String,
    pub inputs: Vec<String>,
    pub outputs: Vec<String>,
}

#[derive(Clone, Debug)]
pub struct Builder {
    pub name: String,
    pub actions: Vec<Action>,
}

#[derive(Clone, Debug)]
pub struct Suite {
    pub name: String,
    pub base_dir: PathBuf,
    pub pattern: String,
    pub builder: Builder,
}

#[derive(Clone, Debug)]
pub struct Program {
    pub name: String,
    pub rel_dir: PathBuf,
    pub source: PathBuf,
    pub suite_name: String,
}

#[derive(Clone, Debug)]
pub struct Job {
    pub generator: Generator,
    pub variant_name: String,
    pub tb: Testbench,
    pub sim: Simulator,
    pub program: Program,
    pub builder: Builder,
    pub final_params: BTreeMap<String, String>,
    pub variables: std::collections::HashMap<String, String>,
}
