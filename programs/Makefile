TARGET ?= minimal
ARCH   := -march=rv32i -mabi=ilp32

# This will be an absolute path passed from the regression script
BUILD_DIR ?= ./build

# Define output file paths using the BUILD_DIR and TARGET
ELF_FILE      := $(BUILD_DIR)/$(TARGET).elf
O_FILE        := $(BUILD_DIR)/$(TARGET).o
ROM_HEX_FILE  := $(BUILD_DIR)/$(TARGET).rom.hex
SRAM_HEX_FILE := $(BUILD_DIR)/$(TARGET).sram.hex
MAP_FILE      := $(BUILD_DIR)/$(TARGET).map
ASM_FILE      := $(BUILD_DIR)/$(TARGET).asm
BIN_FILE      := $(BUILD_DIR)/$(TARGET).bin

CRT_FILE =
CRT_O_FILE =
ifneq ($(wildcard $(TARGET).c),)
	CRT_FILE += $(PROJ_DIR)/programs/crt.s
	CRT_FILE += $(PROJ_DIR)/programs/crt.o
endif

TOOL_PREFIX := riscv32-unknown-elf-
IMAGE_NAME  := $(DOCKER_TOOLCHAIN_IMAGE)

DOCKER_USER_FLAGS := --rm --user "$$(id -u):$$(id -g)" -v "$${PROJ_DIR}:$${PROJ_DIR}" --workdir "$$(pwd)"
DOCKER_IMAGE_CHECK = $(shell docker images -q $(IMAGE_NAME) 2> /dev/null)

CC      := docker run $(DOCKER_USER_FLAGS) $(IMAGE_NAME) $(TOOL_PREFIX)gcc
OBJCOPY := docker run $(DOCKER_USER_FLAGS) $(IMAGE_NAME) $(TOOL_PREFIX)objcopy
OBJDUMP := docker run $(DOCKER_USER_FLAGS) $(IMAGE_NAME) $(TOOL_PREFIX)objdump

.PHONY: all hex asm clean

all: hex

hex: $(ROM_HEX_FILE) $(SRAM_HEX_FILE)

asm: $(ASM_FILE)

$(ROM_HEX_FILE): $(ELF_FILE) | docker-image-build
	@echo "Converting ELF to intermediate HEX (ROM)..."
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O verilog --verilog-data-width 4 --only-section=.text* $< $(BUILD_DIR)/$(TARGET).tmp.hex
	@echo "Formatting final ROM.HEX file..."
	@cat $(BUILD_DIR)/$(TARGET).tmp.hex | tr ' ' '\n' | tr -d '\r' > $@
	@rm -f $(BUILD_DIR)/$(TARGET).tmp.hex

$(SRAM_HEX_FILE): $(ELF_FILE) | docker-image-build
	@echo "Converting ELF to intermediate HEX (SRAM)..."
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O verilog --verilog-data-width 4 --only-section=.data* --only-section=.sdata* --only-section=.bss* --only-section=.sbss* $< $(BUILD_DIR)/$(TARGET).tmp.hex
	@echo "Formatting final SRAM.HEX file..."
	@cat $(BUILD_DIR)/$(TARGET).tmp.hex | tr ' ' '\n' | tr -d '\r' > $@
	@rm -f $(BUILD_DIR)/$(TARGET).tmp.hex

$(BIN_FILE): $(ELF_FILE) | docker-image-build
	@echo "Converting ELF to raw binary..."
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary --gap-fill 0 $< $@

$(ASM_FILE): $(ELF_FILE) | docker-image-build
	@echo "Disassembling ELF to ASM..."
	@mkdir -p $(dir $@)
	$(OBJDUMP) -d $< > $@

$(ELF_FILE): $(CRT_O_FILE) $(O_FILE) | docker-image-build
	@echo "Linking object file..."
	@mkdir -p $(dir $@)
	$(CC) $(ARCH) -o $@ $^ -T link.ld -nostdlib -Wl,-Map,$(MAP_FILE)

$(O_FILE): $(wildcard $(TARGET).s) $(wildcard $(TARGET).c) | docker-image-build
	@echo "Compiling $<..."
	@mkdir -p $(dir $@)
	$(CC) $(ARCH) -c -o $@ $<

$(PROJ_DIR)/programs/crt.o: $(PROJ_DIR)/programs/crt.s
	@echo "Compiling $<..."
	@mkdir -p $(dir $@)
	$(CC) $(ARCH) -c -o $@ $<

docker-image-build:
	@if [ -z "$(DOCKER_IMAGE_CHECK)" ]; then \
		echo "Docker image '$(IMAGE_NAME)' not found, building..."; \
		docker build -t $(IMAGE_NAME) $(TOOLCHAIN_DIR); \
	fi

clean:
	@echo "Cleaning up build directory: $(BUILD_DIR)..."
	@find . -type f \( -name "*.o" -o -name "*.elf" -o -name "*.map" -o -name "*.rom.hex" -o -name "*.sram.hex" \) -delete
	@rm -rf $(BUILD_DIR)
