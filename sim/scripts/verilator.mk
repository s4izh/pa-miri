TOP_MODULE      := top_tb_wrapper

COMPILER        := verilator
COMPILE_FLAGS   := --cc --exe --build -O3 --trace --timing\
                   -f $(PROJ_ROOT)/$(FILELIST) --top-module $(TOP_MODULE)
COMPILED_FILE   := $(BUILD_DIR)/V$(TOP_MODULE)
COMPILE_COMMAND := $(COMPILER) --Mdir $(BUILD_DIR) $(COMPILE_FLAGS)

VCD_FILE        := $(BUILD_DIR)/waveform.vcd
SIMULATOR       := ./V$(TOP_MODULE)
SIM_FLAGS       := +VCD_FILE=$(VCD_FILE) -fst $(PLUSARGS)
VCD_FILE        := $(BUILD_DIR)/waveform.vcd
SIM_COMMAND     := $(SIMULATOR)
