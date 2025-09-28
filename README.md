# pa-miri

Simple SystemVerilog Processor Development Environment

This repository contains a minimal SystemVerilog development environment for processor design and simulation.

## Files

- `simple_processor.sv` - A basic SystemVerilog processor module with:
  - 4-state FSM (IDLE, LOAD, PROC, OUT)
  - 8-bit data processing
  - Clock and reset functionality
  - Simple increment operation

- `simple_processor_tb.sv` - Comprehensive testbench that:
  - Tests multiple input values
  - Verifies state transitions
  - Checks overflow behavior
  - Provides detailed simulation output

- `Makefile` - Build automation with targets for:
  - Compilation, simulation, syntax checking
  - Waveform generation
  - Clean up operations

## Prerequisites

- Icarus Verilog (iverilog) - SystemVerilog compiler and simulator
- VVP - Verilog runtime engine

Install on Ubuntu/Debian:
```bash
sudo apt update
sudo apt install iverilog
```

## Usage

### Basic simulation
```bash
make all
# or simply
make
```

### Available make targets
```bash
make compile   # Compile SystemVerilog files
make simulate  # Run simulation
make waves     # Generate VCD waveform file
make check     # Syntax check only
make clean     # Remove generated files
make help      # Show all available targets
```

### Expected output
The simulation should show:
- State transitions for the processor FSM
- Test results for different input values
- Proper overflow handling (0xFF + 1 = 0x00)

All tests should show "TEST PASS" messages, indicating the processor is working correctly.