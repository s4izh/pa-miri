TOP_MODULE     := top_tb_wrapper

CONTAINER := $(PROJ_DIR)/tools/vsim_container.sh

WORK_DIR       := $(BUILD_DIR)/work

COMPILER       := $(CONTAINER) vlog
COMPILED_FILE  := $(WORK_DIR)/_info
COMPILE_FLAGS  := -sv -createlib -work $(WORK_DIR)
COMPILE_COMMAND := $(COMPILER) $(COMPILE_FLAGS) $(SV_FILES)

WAVE_FILE      ?= $(BUILD_DIR)/waveform.vcd
SIMULATOR      := $(CONTAINER) vsim
SIM_FLAGS      := -c -work $(WORK_DIR) -l $(LOG_FILE) +VCD_FILE=$(WAVE_FILE) $(PLUSARGS) $(TOP_MODULE) -do \"run -all\" -do \"exit\"
SIM_COMMAND    := $(SIMULATOR) $(SIM_FLAGS)
CLEAN_COMMAND  := sudo rm -rf $(BUILD_DIR)
