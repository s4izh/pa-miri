use crate::core::*;
use glob::glob;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct ResolvedAction {
    pub rule_name: String,
    pub inputs: Vec<PathBuf>,  // physical files for Ninja graph (build line)
    pub outputs: Vec<PathBuf>, // physical files for Ninja graph (build line)
    pub variables: HashMap<String, String>, // variables to fill the rule template
}

#[derive(Debug, Clone)]
pub struct SoftwareJob {
    pub suite_name: String,
    pub program_id: String,
    pub rel_path: PathBuf, // e.g., "rtype/add"
    pub actions: Vec<ResolvedAction>,
    pub artifacts: HashMap<String, PathBuf>,
}

#[derive(Clone, Debug)]
pub struct ResolvedSharedJob {
    pub name: String,
    pub artifact_path: PathBuf,
    pub action_name: String,
    pub vars: HashMap<String, String>,
    pub inputs: Vec<PathBuf>,
}

pub fn resolve_suite(
    config: &Config,
    suite_name: &str,
    silo: &crate::silo::SiloResolver,
) -> anyhow::Result<Vec<SoftwareJob>> {
    let suite = &config.suites.get(suite_name).ok_or_else(|| anyhow::anyhow!("Suite name not found '{}'", suite_name))?;
    let tool = &config.tools[&suite.tool];
    let mut jobs = Vec::new();

    // TODO: maybe something better?
    // discover programs using the glob pattern programs/tohost_tests/**/*.s
    let pattern = suite.base_dir.join(&suite.pattern);
    let entries = glob(pattern.to_str().expect("Invalid glob pattern"))?;

    for entry in entries.flatten() {
        if entry.is_file() {
            // calculate the relative path from the base_dir
            // example: programs/tohost_tests/rtype/add.s -> rtype/add.s
            let rel_to_base = entry.strip_prefix(&suite.base_dir)?;

            // get the directory part and the name part
            // example: rtype/add.s -> rtype/
            let rel_dir = rel_to_base.parent().unwrap_or(Path::new(""));
            let file_stem = entry.file_stem().unwrap().to_str().unwrap();

            // this is our unique program ID and its relative path in the build silo
            let program_id = file_stem.to_string();
            let rel_path_in_silo = rel_dir.join(&program_id);

            let rel_path = rel_to_base.with_extension("");

            // resolve the silo directory
            let sw_dir = silo.sw_dir(suite_name, &rel_path);

            let mut context_vars = suite.default_vars.clone();
            // use program_id for overrides
            if let Some(ov) = suite.program_overrides.get(&program_id) {
                context_vars.extend(ov.vars.clone());
            }

            let mut artifact_paths = HashMap::new();
            for action in &tool.actions {
                for art in &action.outputs {
                    artifact_paths.insert(art.name.clone(), sw_dir.join(&art.filename));
                }
            }

            let mut resolved_actions = Vec::new();
            for action in &tool.actions {
                let mut n_vars = HashMap::new();

                if action.command.contains("$out_dir") {
                    n_vars.insert("out_dir".into(), sw_dir.to_string_lossy().to_string());
                }
                if action.command.contains("$in") {
                    n_vars.insert("in".into(), entry.to_string_lossy().to_string());
                }
                for (k, v) in &context_vars {
                    if action.command.contains(&format!("${}", k)) {
                        n_vars.insert(k.clone(), v.clone());
                    }
                }
                for (name, path) in &artifact_paths {
                    if action.command.contains(&format!("${}", name)) {
                        n_vars.insert(name.clone(), path.to_string_lossy().to_string());
                    }
                }

                let phys_ins = if action.inputs.is_empty() {
                    vec![entry.clone()]
                } else {
                    action
                        .inputs
                        .iter()
                        .map(|name| artifact_paths.get(name).unwrap().clone())
                        .collect()
                };

                let phys_outs = action
                    .outputs
                    .iter()
                    .map(|art| artifact_paths.get(&art.name).unwrap().clone())
                    .collect();

                resolved_actions.push(ResolvedAction {
                    rule_name: format!("{}_{}", tool.name, action.name),
                    inputs: phys_ins,
                    outputs: phys_outs,
                    variables: n_vars,
                });
            }
            jobs.push(SoftwareJob {
                suite_name: suite_name.to_string(),
                program_id: program_id,
                rel_path: rel_path_in_silo,
                actions: resolved_actions,
                artifacts: artifact_paths,
            });
        }
    }
    Ok(jobs)
}

pub fn resolve_shared_jobs(config: &Config, silo: &crate::silo::SiloResolver) -> anyhow::Result<HashMap<String, ResolvedSharedJob>> {
    let mut resolved = HashMap::new();
    for (name, job) in &config.shared_jobs {
        let tool = &config.tools[&job.tool];
        let sw_dir = silo.root.join("sw").join("shared").join(name);
        std::fs::create_dir_all(&sw_dir)?;

        // We assume the first action of the tool creates the primary library
        let action = &tool.actions[0];
        let artifact = &action.outputs[0];
        let artifact_path = sw_dir.join(&artifact.filename);

        let mut vars = job.var_overrides.clone();
        vars.insert("out_dir".to_string(), sw_dir.to_string_lossy().to_string());
        vars.insert(artifact.name.clone(), artifact_path.to_string_lossy().to_string());

        resolved.insert(name.clone(), ResolvedSharedJob {
            name: name.clone(),
            artifact_path,
            action_name: format!("{}_{}", tool.name, action.name),
            vars,
            inputs: job.inputs.clone(),
        });
    }
    Ok(resolved)
}
