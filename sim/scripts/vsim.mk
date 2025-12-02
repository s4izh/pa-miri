TOP_MODULE     := top_tb_wrapper

CONTAINER := $(PROJ_DIR)/tools/vsim_container.sh

WORK_DIR       := $(BUILD_DIR)/work

COMPILER       := $(CONTAINER) vlog
COMPILED_FILE  := $(WORK_DIR)/_info
COMPILE_FLAGS  := -sv -createlib -work $(WORK_DIR)
COMPILE_COMMAND := $(COMPILER) $(COMPILE_FLAGS) $(SV_FILES)

WAVE_FILE      ?= $(BUILD_DIR)/waveform.vcd
SIMULATOR      := $(CONTAINER) vsim
SIM_FLAGS      := -c -work $(WORK_DIR) -l $(LOG_FILE) +VCD_FILE=$(WAVE_FILE) -wlf $(WAVE_FILE).wlf $(PLUSARGS) $(TOP_MODULE) -do \"log -r /*\" -do \"run -all\" -do \"quit -sim\"
SIM_COMMAND    := $(SIMULATOR) $(SIM_FLAGS)
CLEAN_COMMAND  := sudo rm -rf $(BUILD_DIR)
