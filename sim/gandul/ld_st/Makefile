ROM_FILE ?= $(PROJ_DIR)/programs/ld_st.rom.hex
SRAM_FILE ?= $(PROJ_DIR)/programs/ld_st.sram.hex

TARGET := ld_st
FILELIST := $(PROJ_DIR)/sim/gandul/$(TARGET)/filelist.f
PLUSARGS := +ROM_FILE=$(ROM_FILE) +SRAM_FILE=$(SRAM_FILE)
include $(PROJ_DIR)/Makefile.in
