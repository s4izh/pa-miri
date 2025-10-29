TOP_MODULE      := top_tb_wrapper

COMPILER        := verilator
COMPILE_FLAGS   := --cc --binary --build -O3 --trace-fst --timing
COMPILED_FILE   := $(BUILD_DIR)/V$(TOP_MODULE)
COMPILE_COMMAND := $(COMPILER) --Mdir $(BUILD_DIR) -f $(FILELIST) --top-module $(TOP_MODULE) $(COMPILE_FLAGS)

WAVE_FILE       ?= $(BUILD_DIR)/waveform.vcd
SIMULATOR       := ./V$(TOP_MODULE)
SIM_FLAGS       := +VCD_FILE=$(WAVE_FILE) $(PLUSARGS)
VCD_FILE        := $(BUILD_DIR)/waveform.vcd
SIM_COMMAND     := $(SIMULATOR) $(SIM_FLAGS) 2>&1 | tee $(LOG_FILE)
CLEAN_COMMAND   := rm -rf $(BUILD_DIR)
