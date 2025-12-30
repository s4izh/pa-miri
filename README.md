# Processor Arquitechture

This document explains the uArch details of each individual assignment.
For details about the project's structure, read [CONTRIBUTING.md](CONTRIBUTING.md).

## 1. RISC-V Processor Architecture assignment 1 (rv_pa1)

This assignment consists of the design of a single-cycle processor (every cycle, 1 instruction is executed). 

### 1.1 ISA

Our implementation uses the RISC-V ISA; specifically, a subset of the RV32I base extension.

We support:

- `lui` and `auipc`
- All arithmetic and logic operations, with register and immediate operands.
- All memory instructions, of 1, 2 and 4 bytes.
- All control-flow instructions, conditional and unconditional.

We currently do not support:
- Fences (`fence`, `fence.tso`)
- `pause`
- `ecall`
- `ebreak`

### 1.2 uArch

This processor's top module is a SoC that contains the execution unit itself,
attached to two memory controllers; the signals of which are exposed as the
interface of the SoC. We have two memory controllers because the addressing
space of the instructions and data memories is disjoint. In each of the
test-benches, the SoC is wired to a ROM and an SRAM, that act as instruction
and data memories. The data memory is required to be synchronously written,
asynchronously read, and byte-addressable. The data-size chosen for the
memories is 32 bits, to at least accommodate full word interactions to not
require any extra logic in the memory controllers.

The execution unit contains the very basics of a datapath: an instruction
decoder, a register file, an ALU, a branch-comparison unit, and some muxes
controlled by decoder's signals. We also have a sign extender that data coming
from memory must go through (for non-unsigned loads of bit-length smaller than
XLEN).

The processor starts execution at imem address **0x1000**, and jumps to imem
address **0x2000** when an exception is triggered. These exceptions can be
caused by miss-aligned memory accesses (both in data and instruction memory) or
illegal instructions. In this simple implementation, no state is saved when
jumping to the service routine, which makes it impossible to recover from an
exception. This is a limitation that we will grow out of in future revisions of
this processor (when CSRs are implemented).

### 1.3 Verification

#### Orchestrator

We created a `cli` that wraps common tasks such as compiling the RTL
files and running simulations. This tool can be found in `tools/orchestrator`.

It autodiscovers the available testbenches and provides a unified interface
to run them. It also allows passing common parameters such as the simulator
to use, the ROM and SRAM files to load, timeouts, etc.

```
$ ./tools/orchestrator --help
usage: orchestrator [-h] [--test {common.memory_controller,common.rv_regfile_test,rv_pa1.all,rv_pa1.anyrom,rv_pa1.ld_st}] [--sim {iverilog,verilator,vsim}] [--rom_file ROM_FILE]
                    [--sram_file SRAM_FILE] [--timeout TIMEOUT] [--verbose]
                    {compile,simulate,waves,clean,lint}

PA Orchestrator

Available tests (select with --test):
  - common.memory_controller
  - common.rv_regfile_test
  - rv_pa1.anyrom
  - rv_pa1.ld_st

Available simulators (select with --sim):
  - iverilog
  - verilator
  - vsim

positional arguments:
  {compile,simulate,waves,clean,lint}
                        Action to perform (compile/simulate/waves/clean/lint).

options:
  -h, --help            show this help message and exit
  --test {common.memory_controller,common.rv_regfile_test,rv_pa1.all,rv_pa1.anyrom,rv_pa1.ld_st}
                        Specific test name (omit for all).
  --sim {iverilog,verilator,vsim}
                        Simulator (default: vsim).
  --rom_file ROM_FILE   Path to file with hex contents of the ROM (default: Empty).
  --sram_file SRAM_FILE
                        Path to file with hex contents of the SRAM (default: Empty).
  --timeout TIMEOUT     Number of cycles after which a timeout is triggered (default: 1000).
  --verbose, -v         Print debug info.
```

#### Simulators

We have tested our implementation in three different simulators,
`vsim`, `iverilog` and `verilator`.
The testbenches are compatible between all three simulators.

#### Testbenches

We have a few testbenches that verify the correct operation
of the processor and different components.

- `rv_pa1.ld_st`: A testbench that verifies load and store instructions. This separate
  testbench was created to isolate load/store instruction testing from the rest of the ISA.
  This is because all the other tests use load/store instructions to report its results.

- `rv_pa1.anyrom`: A testbench that loads a user-provided ROM file (and SRAM file)
  and runs it in the processor. We use this testbench to run the ISA tests and C benchmarks.

- `common.memory_controller`: A testbench used to verify the memory controller.

- `common.rv_regfile_test`: A testbench used to verify the register file.

#### ISA tests

We have created a set of tests that cover all the instructions
implemented in the ISA.

These tests are located in the `programs/tohost_tests/` folder.
All tests are compiled and run by the `./tools/regression` script,
a tool that wraps `orchestrator` to perform regression tests.

We used a very simplistic `tohost` mechanism so the tests
can report their results from the assembly code itself.

#### C benchmarks

We have a set of C programs that can be used as benchmarks
for the processor. These programs are located in the
`programs/benchmarks/` folder.

## RISC-V Processor Architecture assignment 2 (rv_pa2)
### 1.1 ISA
Exact same RV32I subset as in *rv_pa1*.

### 1.2 uArch
The main differences with the previous assignment lies in the fact that the
datapath is pipelined: 5 stages (Fetch, Decode, Execute, Memory and Write-back),
with a full set of bypasses to decode:
- E->D
- M->D
- W->D

And one missing bypass for instructions that do not use stage execute, and depend
on a load:
- M->E

A first implementation of this bypass resulted in a faulty processor, which is
why we opted to hold this feature until the next assignment.
Since there are not too many cases that take advantage of this bypass, and the
consequence is only blocking for a single cycle, the performance loss is
manageable. As said before, future assignments will include this in their
datapath.

Two components now necessary to control all of this are: the forwarding unit,
and the hazard detection unit. Both of them receive signals from the pipeline,
and determine if bypasses are feasible and if a hazard is present in our pipeline,
respectively.

### 1.3 Verification
Our verification environment is very similar to that seen in *rv_pa1*. We still
rely on scripts like `tools/orchestrator` to correctly manage all operations on
our models, and we added some convenience scripts for developing and debugging
(`tools/{select_wave, benchmarks, view_konata}`). Precisely this last script is
used to extract Konata traces from the inner signals of our datapath, and
create a simpler visualization of its state. These output are generated by a
new component in the testbench: `konata_tracer`. The state of the Konata logs
is unreliable at the moment, but useful for debugging nonetheless
(improvements coming in rv_a2).

Support for iVerilog has been dropped. Too many of the language features we were
using (supported in both other sims) were not supported by iVerilog, which was
pulling us back, by forcing us to refactor those unsupported features. We opted
to stop using it altogether, and rely on Verilator and Modelsim.


## RISC-V Processor Architecture assignment 3 (rv_pa3)
### 1.1 ISA
Exact same RV32I subset as in *rv_pa2*.

### 1.2 uArch
The missing bypass for instructions that do not use stage execute, and depend
on a load has been implemented this time around.

- M->E

This bypass is really useful when a store is right behind a load that produces
the register value that the store will send to memory (memcpy).

With respect to the caches, we designed two (data and instructions) with a
similar architecture. We divided the caches between a simple front-end
(`Xcache_controller`), and an engine (`Xcache`), threaded together in a single
module (`Xcache_wrapper`). The front-end is responsible for detecting
exceptions, and notifying the requester, without affecting the underlying
engine. The controller communicates only valid requests to the engine, and
supplies the data aligned with the cache-line size (128b). When a read request
produces it's result, the controller aligns the data back to the width that the
requester supplied (32b, 16b, 8b). The engine is a Mealy state machine that
stays on state IDLE as long as read hits are requested. When there is a load
miss, or a write hit, or a write miss, we jump to a series of states that
interact with memory to fill the line that we need.

<!-- dcache -->
We implemented 4-way set-associative data cache with 4 sets and 128-bit
cache-lines. It uses 2 bits from the address to select the set and employs a
FIFO replacement policy when a set is full. The store policy is write-through
and write-allocate. A four-state FSM manages the timing, using a valid-ready
handshake to stall the core while waiting for slow memory responses. It
features a combinational bypass that delivers data from memory directly to the
core on the same cycle it arrives, minimizing the latency of a cache miss.

<!-- icache -->
The icache does the exact same as the dcache, but without all of the write logic.
Therefore, the FSM has 2 states instead of 4.



### 1.3 Verification
The verification environment for this deliverable has changed quite a bit.
A new type of testbench called `rv_pa3.cosim` enables cosimulation through the
DPI-C calling convention for executing binaries in simulation. The code of
the reference model can be seen in directory `cosim/`. This new testbench
initializes de cpp golden model with the same parameters as the RTL. The
cosimulator is then single stepped at ISA level (just like a single cycle hart,
such as `rv_pa1`) and the results are compared with the ones produced by the RTL
(program counter, instruction word, and destination register value). This
process is repeated every time an instruction completes. If the end of the
program (write to `tohost`) is reached without any mismatches, the test is
considered as "passed".

Even with the limited uArch visibility that the ISA-level simulation provides,
this testbench has been crucial in the verification of this deliverable, as it
stops simulation as soon as a mismatch is found. This allows us to write tests
that do not need to check themselves with potentially-faulty instructions. Not
all behaviours of the uArch are captured in the reference model; however
comparing the instruction's results is enough of a check for us to assert that
the core follows the ISA.

We also considered an open source Instruction Set Simulator (ISS) such as Spike
or Dromajo. We ended gravitating towards developing our own because of code
familiarity, and nuances of this project that don't follow the ISA religiously
(severed instruction and data memories, lack of CSRs, uncomplete support of
RV32I instructions, amongst others). Therefore, a tailor-made solution like
ours is much more fitting for this particular instance.

## RISC-V Processor Architecture Final assignment (Gandul Lentium)
### 1.1 ISA
### 1.2 uArch
### 1.3 Verification
