#
# Top-Level Makefile to dispatch simulation tasks
#
export PROJ_ROOT := $(shell pwd)

# --- Default Goal ---
.PHONY: all
all:
	@echo "Please specify a target. Try 'make help'."

# --- Main Targets ---
.PHONY: test_regfile
test_regfile:
	@echo "===== [TEST] Testing Common Component: Register File ====="
	@$(MAKE) -C sim/common/regfile_test

# --- Utility Targets ---
.PHONY: clean help
clean:
	@echo "===== [CLEAN] Removing all build artifacts ====="
	rm -rf build/

help:
	@echo "Usage: make <target> [SIM=<simulator>]"
	@echo ""
	@echo "Available Component Tests:"
	@echo "  make test_regfile       - Run the standalone test for the register file."
	@echo ""
	@echo "Utility:"
	@echo "  make clean              - Remove all generated files."
	@echo ""
	@echo "Options:"
	@echo "  SIM=iverilog            - (Default) Use Icarus Verilog."
