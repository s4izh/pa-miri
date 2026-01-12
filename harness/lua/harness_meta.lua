---@meta

---@class Artifact
---@field name string
---@field filename string

---@class Action
---@field name string
---@field command string
---@field inputs string[]
---@field outputs Artifact[]

---@class harness
harness = {}

---@param config {name: string, actions: Action[]}
function harness.add_tool(config) end

---@param config {name: string, compile_rule: string, outputs: Artifact[], default_run_rule: string}
function harness.add_simulator(config) end

---@param config {name: string, testbench: string, param_sets: string[], suites: string[], simulators: string[]}
function harness.add_experiment(config) end

---@param config {name: string, filelist: string, run_template: string}
function harness.add_testbench(config) end

---@param config {name: string, defines: table<string, string>, plusargs?: string[]}
function harness.add_param_set(config) end

---@param dir string
function harness.set_build_dir(dir) end

---@param config {name: string, base_dir: string, pattern: string, tool?: string, logical_name?: string, vars: table<string, string>, plusargs: string[]}
function harness.add_suite(config) end
