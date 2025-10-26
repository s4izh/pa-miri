ROM_FILE ?=

TARGET := all
FILELIST := $(PROJ_DIR)/sim/rv_processor_a1_unicycle/$(TARGET)/filelist.f
PLUSARGS := +ROM_FILE=$(PROGRAMS_DIR)/all.hex
ROM_COMPILE_COMMAND := make -C $(PROGRAMS_DIR) TARGET=all
include $(PROJ_DIR)/Makefile.in
