ROM_FILE ?=
SRAM_FILE ?=
TIMEOUT ?=

TARGET := anyrom
FILELIST := $(PROJ_DIR)/sim/rv_processor_a1_unicycle/$(TARGET)/filelist.f
PLUSARGS := +ROM_FILE=$(ROM_FILE) +SRAM_FILE=$(SRAM_FILE) +TIMEOUT_CYCLES=$(TIMEOUT)
include $(PROJ_DIR)/Makefile.in
