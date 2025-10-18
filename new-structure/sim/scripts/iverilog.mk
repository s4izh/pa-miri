TOP_MODULE     := top_tb_wrapper

COMPILER       := iverilog
COMPILE_FLAGS  := -g2012 -Wall $(SV_FILES) -s $(TOP_MODULE)
COMPILED_FILE  := $(VVP_FILE)

SIMULATOR      := vvp
SIM_FLAGS      := +VCD_FILE=waveform.vcd
SIM_COMMAND    := $(SIMULATOR) sim.vvp $(SIM_FLAGS)
