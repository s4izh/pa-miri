# Harness README: Technical Overview

**Harness** is a Rust-based orchestrator designed for Hardware/Software
co-design. It manages the complexity of verifying RTL designs against various
software workloads across different simulators. By using **Ninja** as its
execution engine, it provides high-performance, parallelized builds while
maintaining strict isolation between different hardware/software combinations.

## Core Concepts

### 1. The Silo (Build Isolation)

Harness prevents artifact contamination by using a "Silo" structure. Every build is unique based on its parameters:

* **Hardware:** `build/hw/<testbench>/<param_set>/<simulator>/`
* **Software:** `build/sw/<suite>/<program>/`
* **Simulation:** `build/sim/<experiment>/<tb>/<ps>/<sim>/<suite>/<program>/`

### 2. Ninja Integration

Instead of running compilers directly, Harness generates a `build.ninja` file. This allows:

* **Massive Parallelism:** Running multiple hardware builds and software compilations simultaneously.
* **Incremental Builds:** Ninja's efficient dependency tracking ensures only changed components are rebuilt.

## Key Components

| Component | Description |
| --- | --- |
| **Tasks** | Run external tasks |
| **Tool** | Defines a software toolchain (e.g., `riscv_gcc`) and its actions (compile, link, objcopy). |
| **ParamSet** | A collection of Verilog macros and defines used to configure the RTL (e.g., Cache sizes). |
| **Suite** | A collection of software programs identified by a glob pattern. |
| **Testbench** | The top-level RTL module to build. |
| **Experiment** | A top-level binding that links a Testbench, a set of ParamSets, and Software Suites. |

---

## Workflow

1. **Configuration:** Define your environment in `harness.lua`. See [../harness.lua](harness.lua) as an example on how to use the API.
2. **Generation:** Run `harness gen` to discover all targets and create the Ninja graph.
3. **Execution:** Run `harness simulate <experiment_name>`.
* Harness filters the required targets.
* Ninja compiles the hardware and software.
* The simulation is triggered via a generated `run.sh` script.


4. **Analysis:** Harness parses simulation logs for results to generate performance reports (Cycles, Instructions, CPI).

---

## Performance Comparison

Harness includes a built-in comparison engine. By specifying a `--baseline`,
you can automatically calculate the speedup of a "Unified Cache" configuration
against a "Base" configuration across an entire suite of tests.

```bash
harness analyze regression --baseline base
```
