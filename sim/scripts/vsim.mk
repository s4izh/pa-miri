TOP_MODULE     := top_tb_wrapper

CONTAINER := $(PROJ_DIR)/utils/vsim_container.sh
# CONTAINER :=

WORK_DIR := $(BUILD_DIR)/work

COMPILER       := $(CONTAINER) vlog
COMPILED_FILE  := $(WORK_DIR)/_info
COMPILE_FLAGS  := -sv -createlib -work $(WORK_DIR)
COMPILE_COMMAND := $(COMPILER) $(COMPILE_FLAGS) $(SV_FILES)

VCD_FILE       := $(BUILD_DIR)/waveform.vcd
SIMULATOR      := $(CONTAINER) vsim
# SIM_FLAGS      := $(PROJ_DIR)/utils/vsim_run.tcl #+VCD_FILE=$(VCD_FILE) $(PLUSARGS)
SIM_FLAGS      := -c -work $(WORK_DIR) -l $(BUILD_DIR)/transcript $(PLUSARGS) $(TOP_MODULE) -do "run" -do "exit"
SIM_COMMAND    := $(SIMULATOR) $(SIM_FLAGS)
