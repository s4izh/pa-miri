TOP_MODULE     := top_tb_wrapper

VSIM := $(PROJ_DIR)/utils/vsim.sh

COMPILER       := $(VSIM)
# COMPILE_FLAGS  := -g2012 -Wall $(SV_FILES) -s $(TOP_MODULE)
COMPILE_FLAGS  := $(PROJ_DIR)/utils/vsim_compile.tcl
COMPILED_FILE  := $(BUILD_DIR)/work
# COMPILE_COMMAND := $(COMPILER) -o $(COMPILED_FILE) $(COMPILE_FLAGS)
COMPILE_COMMAND := export SV_FILES="$(SV_FILES)"; $(COMPILER) $(COMPILE_FLAGS)

VCD_FILE       := $(BUILD_DIR)/waveform.vcd
SIMULATOR      := $(VSIM)
SIM_FLAGS      := $(PROJ_DIR)/utils/vsim_compile.tcl +VCD_FILE=$(VCD_FILE) $(PLUSARGS)
SIM_COMMAND    := $(SIMULATOR) $(COMPILED_FILE) $(SIM_FLAGS)
