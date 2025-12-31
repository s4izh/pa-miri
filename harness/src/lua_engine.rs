use crate::core::*;
use mlua::{Lua, LuaSerdeExt, Table, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

pub fn load_config(path: &Path) -> anyhow::Result<(Config, Arc<Lua>)> {
    let lua = Arc::new(Lua::new());
    let config = Arc::new(Mutex::new(Config::new()));

    let harness = lua.create_table().map_err(|e| anyhow::anyhow!(e.to_string()))?;

    harness.set("list_files", lua.create_function(|_, pattern: String| {
        let mut files = Vec::new();
        for entry in glob::glob(&pattern).map_err(|e| mlua::Error::RuntimeError(e.to_string()))? {
            if let Ok(p) = entry {
                if p.is_file() {
                    files.push(p.to_string_lossy().to_string());
                }
            }
        }
        Ok(files)
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
    .map_err(|e| anyhow::anyhow!(e.to_string()))?;

    harness.set("abspath", lua.create_function(|_, path: String| {
        let p = std::path::PathBuf::from(path);
        if p.is_absolute() {
            Ok(p.to_string_lossy().to_string())
        } else {
            let current = std::env::current_dir()
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            Ok(current.join(p).to_string_lossy().to_string())
        }
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
    .map_err(|e| anyhow::anyhow!(e.to_string()))?;

    harness.set("pwd", lua.create_function(|_, ()| {
        let current = std::env::current_dir()
            .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        Ok(current.to_string_lossy().to_string())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
    .map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    let l_handle = Arc::clone(&lua);
    harness.set("add_task", lua.create_function(move |_, table: Table| {
        let name: String = table.get("name")?;
        let namespace: String = table.get("tasks_namespace").unwrap_or_else(|_| "default".to_string());
        
        let build_dir_base = c.lock().unwrap().build_dir.clone();
        let project_root = std::env::current_dir().map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        
        // RELATIVE PATH (For Ninja Identities)
        // build/tasks/<namespace>/<name>
        let rel_silo_path = PathBuf::from(&build_dir_base)
            .join("tasks")
            .join(&namespace)
            .join(&name);
            
        // 2. ABSOLUTE PATH (For Shell/Make Execution)
        // /home/.../build/tasks/<namespace>/<name>
        let abs_silo_path = project_root.join(&rel_silo_path);
        
        std::fs::create_dir_all(&abs_silo_path).map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;

        let outputs_raw: HashMap<String, String> = table.get("outputs")?;
        let mut resolved_outputs = Vec::new();
        let lua_outputs = l_handle.create_table()?;

        for (logical, filename) in outputs_raw {
            let rel_output_path = rel_silo_path.join(filename);
            // we return the relative path to Lua so handles are ninja-friendly
            lua_outputs.set(logical.clone(), rel_output_path.to_string_lossy().to_string())?;
            resolved_outputs.push(rel_output_path);
        }

        // dual-path injection
        let mut task_vars: HashMap<String, String> = table.get("vars").unwrap_or_default();
        
        // provide both flavors to the user
        task_vars.insert("out_dir".into(), rel_silo_path.to_string_lossy().to_string());
        task_vars.insert("abs_out_dir".into(), abs_silo_path.to_string_lossy().to_string());
        
        if let Ok(sd) = table.get::<String>("source_dir") {
            let abs_source = project_root.join(&sd);
            task_vars.insert("source_dir".into(), sd); // relative for Ninja
            task_vars.insert("abs_source_dir".into(), abs_source.to_string_lossy().to_string()); // absolute for shell
        }

        let task = Task {
            namespace,
            name: name.clone(),
            command: table.get("command")?,
            inputs: table.get::<Vec<String>>("inputs")?.into_iter().map(PathBuf::from).collect(),
            outputs: resolved_outputs,
            vars: task_vars,
        };

        c.lock().unwrap().tasks.push(task);

        let handle = l_handle.create_table()?;
        handle.set("name", name)?;
        handle.set("outputs", lua_outputs)?;
        Ok(handle)
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
    .map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    let l_tb = Arc::clone(&lua);
    harness.set("add_testbench", lua.create_function(move |_, table: Table| {
        let name: String = table.get("name")?;
        
        if let Ok(f) = table.get::<mlua::Function>("pre_compile") {
            let key = l_tb.create_registry_value(f)?;
            c.lock().unwrap().hooks.testbench.insert(
                (name.clone(), TestbenchHook::PreCompile), 
                Arc::new(key)
            );
        }

        let tb: Testbench = l_tb.from_value(Value::Table(table))
            .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        c.lock().unwrap().testbenches.insert(tb.name.clone(), tb);
        Ok(())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
    .map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    harness.set("add_tool", lua.create_function(move |lua, table: Table| {
        let tool: Tool = lua.from_value(Value::Table(table))
            .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        c.lock().unwrap().tools.insert(tool.name.clone(), tool);
        Ok(())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?).map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    harness.set("add_simulator", lua.create_function(move |lua, table: Table| {
        let sim: Simulator = lua.from_value(Value::Table(table))
            .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        c.lock().unwrap().simulators.insert(sim.name.clone(), sim);
        Ok(())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?).map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    harness.set("add_suite", lua.create_function(move |lua, table: Table| {
        let suite: Suite = lua.from_value(Value::Table(table))
            .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        c.lock().unwrap().suites.insert(suite.name.clone(), suite);
        Ok(())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?).map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    harness.set("add_param_set", lua.create_function(move |lua, table: Table| {
        let ps: ParamSet = lua.from_value(Value::Table(table))
            .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        c.lock().unwrap().param_sets.insert(ps.name.clone(), ps);
        Ok(())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?).map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    harness.set("add_experiment", lua.create_function(move |lua, table: Table| {
        let exp: Experiment = lua.from_value(Value::Table(table))
            .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
        c.lock().unwrap().experiments.push(exp);
        Ok(())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?).map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let c = Arc::clone(&config);
    harness.set("set_build_dir", lua.create_function(move |_, dir: String| {
        c.lock().unwrap().build_dir = dir;
        Ok(())
    }).map_err(|e| anyhow::anyhow!(e.to_string()))?).map_err(|e| anyhow::anyhow!(e.to_string()))?;

    lua.globals().set("harness", harness).map_err(|e| anyhow::anyhow!(e.to_string()))?;

    let script = std::fs::read_to_string(path)?;
    lua.load(&script).exec()
        .map_err(|e| anyhow::anyhow!("Error in harness.lua: {}", e))?;

    let final_config = config.lock().unwrap().clone();
    Ok((final_config, lua))
}
