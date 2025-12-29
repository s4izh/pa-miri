-f $(PROJ_DIR)/rtl/rv_pa3/rv_pa3.f

$(PROJ_DIR)/rtl/common/valid_delayer.sv
$(PROJ_DIR)/rtl/common/rom.sv
$(PROJ_DIR)/rtl/common/sram.sv

$(PROJ_DIR)/tb/rv_pa3/tb_anyrom.sv
$(PROJ_DIR)/tb/common_tb/rv32_util_pkg.sv
$(PROJ_DIR)/tb/common_tb/konata_tracer.sv
$(PROJ_DIR)/tb/common_tb/top_tb_wrapper.sv
