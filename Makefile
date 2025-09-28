CORE ?= pa_cpu_mini1

BUILD_DIR := build
CORE_DIR  := cores/$(CORE)
LIB_DIR   := lib

TOP_MODULE := $(CORE)_tb

IVERILOG := iverilog
VVP      := vvp

IV_FLAGS := -g2012 -Wall -I$(CORE_DIR)/src -I$(LIB_DIR)/src

SV_FILES := $(wildcard $(CORE_DIR)/src/*.sv) $(wildcard $(CORE_DIR)/tb/*.sv) $(wildcard $(LIB_DIR)/src/*.sv)

VVP_FILE := $(BUILD_DIR)/$(CORE)/$(CORE).vvp
VCD_DIR  := $(dir $(VVP_FILE))
VCD_FILE ?= $(VCD_DIR)$(CORE).vcd

.DEFAULT_GOAL := help

.PHONY: all compile simulate waves check clean cores help

all: simulate

$(VVP_FILE): $(SV_FILES)
	@mkdir -p $(VCD_DIR)
	$(IVERILOG) $(IV_FLAGS) -o $@ -s $(TOP_MODULE) $(SV_FILES)

compile: $(VVP_FILE)

simulate: $(VVP_FILE)
	@mkdir -p $(dir $(VCD_FILE))
	$(VVP) $< +VCD_FILE=$(VCD_FILE)

waves: simulate
	surfer $(VCD_FILE)

check:
	$(IVERILOG) $(IV_FLAGS) -t null $(SV_FILES)

clean:
	rm -rvf $(BUILD_DIR)

cores:
	@echo "Available cores:"
	@basename -a cores/*

help:
	@echo "Usage: make <target> [CORE=<core_name>]"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Compile and simulate the core (default)"
	@echo "  simulate   - Run the simulation"
	@echo "  compile    - Compile the source files if they have changed"
	@echo "  waves      - Run simulation and generate a VCD waveform"
	@echo "  check      - Check SystemVerilog syntax"
	@echo "  clean      - Remove all generated files"
	@echo "  cores      - List all available cores"
	@echo "  help       - Show this help message"
