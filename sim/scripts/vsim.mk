TOP_MODULE     := top_tb_wrapper

CONTAINER := $(PROJ_DIR)/utils/vsim_container.sh
# CONTAINER :=


COMPILER       := $(CONTAINER) vlog
COMPILED_FILE  := $(BUILD_DIR)/build
COMPILE_FLAGS  := -sv -createlib -work $(COMPILED_FILE)
COMPILE_COMMAND := $(COMPILER) $(COMPILE_FLAGS) $(SV_FILES)

TRANSCRIPT_FILE := $(BUILD_DIR)/transcript
VCD_FILE       := $(BUILD_DIR)/waveform.vcd
SIMULATOR      := $(CONTAINER) vsim
# SIM_FLAGS      := $(PROJ_DIR)/utils/vsim_run.tcl #+VCD_FILE=$(VCD_FILE) $(PLUSARGS)
SIM_FLAGS      := -c -work $(COMPILED_FILE) -l $(BUILD_DIR)/build/transcript $(PLUSARGS) -do "set NoQuitOnFinish 1" -do "run -all;"
SIM_COMMAND    := $(SIMULATOR) $(SIM_FLAGS)
