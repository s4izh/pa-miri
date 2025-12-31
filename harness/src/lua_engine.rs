use crate::core::*;
use mlua::{Lua, LuaSerdeExt, Table};
use std::path::Path;
use std::sync::{Arc, Mutex};

pub fn load_config(path: &Path) -> anyhow::Result<Config> {
    let config = Arc::new(Mutex::new(Config::new()));

    {
        let lua = Lua::new();
        let harness = lua.create_table().map_err(|e| anyhow::anyhow!(e.to_string()))?;

        // harness.add_tool
        let c = Arc::clone(&config);
        harness.set("add_tool", lua.create_function(move |lua, table: Table| {
            let tool: Tool = lua.from_value(mlua::Value::Table(table))
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            c.lock().unwrap().tools.insert(tool.name.clone(), tool);
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
        .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        // harness.add_simulator
        let c = Arc::clone(&config);
        harness.set("add_simulator", lua.create_function(move |lua, table: Table| {
            let sim: Simulator = lua.from_value(mlua::Value::Table(table))
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            c.lock().unwrap().simulators.insert(sim.name.clone(), sim);
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
        .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        // harness.add_suite
        let c = Arc::clone(&config);
        harness.set("add_suite", lua.create_function(move |lua, table: Table| {
            let suite: Suite = lua.from_value(mlua::Value::Table(table))
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            c.lock().unwrap().suites.insert(suite.name.clone(), suite);
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
        .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        // harness.add_testbench
        let c = Arc::clone(&config);
        harness.set("add_testbench", lua.create_function(move |lua, table: Table| {
            let tb: Testbench = lua.from_value(mlua::Value::Table(table))
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            c.lock().unwrap().testbenches.insert(tb.name.clone(), tb);
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
        .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        // harness.add_param_set
        let c = Arc::clone(&config);
        harness.set("add_param_set", lua.create_function(move |lua, table: Table| {
            let ps: ParamSet = lua.from_value(mlua::Value::Table(table))
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            c.lock().unwrap().param_sets.insert(ps.name.clone(), ps);
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
        .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        let c = Arc::clone(&config);
        harness.set("add_shared_job", lua.create_function(move |lua, table: mlua::Table| {
            let job: SharedJob = lua.from_value(mlua::Value::Table(table))
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            c.lock().unwrap().shared_jobs.insert(job.name.clone(), job);
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        // harness.add_experiment
        let c = Arc::clone(&config);
        harness.set("add_experiment", lua.create_function(move |lua, table: Table| {
            let exp: Experiment = lua.from_value(mlua::Value::Table(table))
                .map_err(|e| mlua::Error::RuntimeError(e.to_string()))?;
            c.lock().unwrap().experiments.push(exp);
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
        .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        let c = Arc::clone(&config);
        harness.set("set_build_dir", lua.create_function(move |_, dir: String| {
            c.lock().unwrap().build_dir = dir;
            Ok(())
        }).map_err(|e| anyhow::anyhow!(e.to_string()))?)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        lua.globals().set("harness", harness)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;

        let script = std::fs::read_to_string(path)?;
        lua.load(&script).exec()
            .map_err(|e| anyhow::anyhow!("Error in harness.lua: {}", e))?;
            
        // End of scope: 'lua' is dropped here, releasing Arc references
    }

    // Now Arc::try_unwrap will succeed because the count is 1
    let mutex = Arc::try_unwrap(config)
        .map_err(|_| anyhow::anyhow!("Internal Error: Lua references to config were not released"))?;
    
    let final_config = mutex.into_inner()
        .map_err(|_| anyhow::anyhow!("Internal Error: Mutex poisoned"))?;

    Ok(final_config)
}
