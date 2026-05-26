PROJ_DIR  := $(realpath ..)
UVM_HOME  := $(PROJ_DIR)/verilator-uvm-example/1800.2-2020.3.1/src
TB_DIR    := $(PROJ_DIR)/fifo_uvm

LOCAL_VLT_BIN = $(PROJ_DIR)/verilator-uvm-example/verilator-src/bin/verilator_bin
LOCAL_VLT     = $(PROJ_DIR)/verilator-uvm-example/verilator-src/bin/verilator
VERILATOR     = $(if $(wildcard $(LOCAL_VLT_BIN)),$(LOCAL_VLT),nix run nixpkgs#verilator --)

SV_FILES := \
    $(TB_DIR)/fifo.sv    \
    $(TB_DIR)/fifo_if.sv \
    $(TB_DIR)/fifo_pkg.sv \
    $(TB_DIR)/tb.sv

compile:
	$(VERILATOR) -Wno-fatal --binary -j $(shell nproc) \
	    --top-module tbench_top \
	    +incdir+$(UVM_HOME) \
	    +incdir+$(TB_DIR) \
	    +define+UVM_NO_DPI \
	    $(UVM_HOME)/uvm_pkg.sv \
	    $(SV_FILES)

run: compile
	./obj_dir/Vtbench_top +UVM_TESTNAME=fifo_test +UVM_NO_RELNOTES

clean:
	rm -rf obj_dir
