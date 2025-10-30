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
This processor's top module is a SoC that contains the execution unit itself, attached to two memory controllers; the signals of which are exposed as the interface of the SoC. We have two memory controllers because the addressing space of the instructions and data memories is disjoint. In each of the test-benches, the SoC is wired to a ROM and an SRAM, that act as instruction and data memories. The data memory is required to be synchronously written, asynchronously read, and byte-addressable. The data-size chosen for the memories is 32 bits, to at least accommodate full word interactions to not require any extra logic in the memory controllers.

The execution unit contains the very basics of a datapath: an instruction decoder, a register file, an ALU, a branch-comparison unit, and some muxes controlled by decoder's signals. We also have a sign extender that data coming from memory must go through (for non-unsigned loads of bit-length smaller than XLEN).

The processor starts execution at imem address **0x1000**, and jumps to imem address **0x2000** when an exception is triggered. These exceptions can be caused by miss-aligned memory accesses (both in data and instruction memory) or illegal instructions. In this simple implementation, no state is saved when jumping to the service routine, which makes it impossible to recover from an exception. This is a limitation that we will grow out of in future revisions of this processor (when CSRs are implemented).

### 1.3 Verification

**TODO**: testbenches

**TODO**: ISA tests

**TODO**: benchmark tests


## RISC-V Processor Architecture assignment 2 (rv_pa2)


## RISC-V Processor Architecture assignment 3 (rv_pa3)

## RISC-V Processor Architecture Final assignment (rv_paf)
