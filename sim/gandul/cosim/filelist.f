-f $(PROJ_DIR)/rtl/gandul/gandul.f

$(PROJ_DIR)/rtl/common/valid_delayer.sv
$(PROJ_DIR)/rtl/common/rom.sv
$(PROJ_DIR)/rtl/common/sram.sv
$(BUILD_DIR)/cosim_dpi.a

$(PROJ_DIR)/tb/common_tb/rv32_util_pkg.sv
$(PROJ_DIR)/tb/common_tb/konata_tracer.sv
$(PROJ_DIR)/tb/gandul/tb_cosim.sv
$(PROJ_DIR)/tb/common_tb/top_tb_wrapper.sv
