# Makefile for Simple Processor SystemVerilog project
# Uses Icarus Verilog for compilation and simulation

# Project configuration
PROJECT_NAME = simple_processor
TOP_MODULE = simple_processor_tb
SV_FILES = simple_processor.sv simple_processor_tb.sv

# Simulation configuration
VVP_FILE = $(PROJECT_NAME).vvp
VCD_FILE = $(PROJECT_NAME).vcd

# Compiler and simulator
IVERILOG = iverilog
VVP = vvp

# Compilation flags
IV_FLAGS = -g2012 -Wall

# Default target
all: compile simulate

# Compile SystemVerilog files
compile: $(VVP_FILE)

$(VVP_FILE): $(SV_FILES)
	@echo "Compiling SystemVerilog files..."
	$(IVERILOG) $(IV_FLAGS) -o $(VVP_FILE) -s $(TOP_MODULE) $(SV_FILES)
	@echo "Compilation successful!"

# Run simulation
simulate: $(VVP_FILE)
	@echo "Running simulation..."
	$(VVP) $(VVP_FILE)
	@echo "Simulation completed!"

# Generate VCD waveform file
waves: $(VVP_FILE)
	@echo "Generating waveform file..."
	$(VVP) $(VVP_FILE) +vcd
	@echo "Waveform file $(VCD_FILE) generated!"

# Clean generated files
clean:
	@echo "Cleaning up..."
	rm -f $(VVP_FILE) $(VCD_FILE)
	@echo "Clean completed!"

# Check syntax without running simulation
check: $(SV_FILES)
	@echo "Checking syntax..."
	$(IVERILOG) $(IV_FLAGS) -t null -o /dev/null $(SV_FILES)
	@echo "Syntax check passed!"

# Show help
help:
	@echo "Available targets:"
	@echo "  all       - Compile and simulate (default)"
	@echo "  compile   - Compile SystemVerilog files"
	@echo "  simulate  - Run simulation"
	@echo "  waves     - Generate VCD waveform file"
	@echo "  check     - Check syntax only"
	@echo "  clean     - Remove generated files"
	@echo "  help      - Show this help message"

.PHONY: all compile simulate waves clean check help