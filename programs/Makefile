TARGET ?= minimal
ARCH   := -march=rv32i -mabi=ilp32

TOOL_PREFIX := riscv32-unknown-elf-
IMAGE_NAME  := $(DOCKER_TOOLCHAIN_IMAGE)

DOCKER_USER_FLAGS := --rm --user "$$(id -u):$$(id -g)" -v "$$(pwd):/work" --workdir /work

DOCKER_IMAGE_CHECK = $(shell docker images -q $(IMAGE_NAME) 2> /dev/null)

CC      := docker run $(DOCKER_USER_FLAGS) $(IMAGE_NAME) $(TOOL_PREFIX)gcc
OBJCOPY := docker run $(DOCKER_USER_FLAGS) $(IMAGE_NAME) $(TOOL_PREFIX)objcopy
OBJDUMP := docker run $(DOCKER_USER_FLAGS) $(IMAGE_NAME) $(TOOL_PREFIX)objdump

XXD  := xxd
CUT  := cut

.PHONY: all hex asm clean

all: hex

hex: $(TARGET).rom.hex $(TARGET).sram.hex

asm: $(TARGET).asm

$(TARGET).rom.hex: $(TARGET).elf | docker-image-build
	@echo "Converting ELF to intermediate HEX..."
	$(OBJCOPY) -O verilog --verilog-data-width 4 --only-section=.text* $< $(TARGET).tmp.hex
	@echo "Formatting final ROM.HEX file (fixing spacing and line endings)..."
	cat $(TARGET).tmp.hex | tr ' ' '\n' | tr -d '\r' > $@
	rm -f $(TARGET).tmp.hex

$(TARGET).sram.hex: $(TARGET).elf | docker-image-build
	@echo "Converting ELF to intermediate HEX..."
	$(OBJCOPY) -O verilog --verilog-data-width 4 --only-section=.data* --only-section=.sdata* --only-section=.bss* --only-section=.sbss* $< $(TARGET).tmp.hex
	@echo "Formatting final SRAM.HEX file (fixing spacing and line endings)..."
	cat $(TARGET).tmp.hex | tr ' ' '\n' | tr -d '\r' > $@
	rm -f $(TARGET).tmp.hex

$(TARGET).bin: $(TARGET).elf | docker-image-build
	@echo "Converting ELF to raw binary..."
	$(OBJCOPY) -O binary --gap-fill 0 $< $@

$(TARGET).asm: $(TARGET).elf | docker-image-build
	@echo "Disassembling ELF to ASM..."
	$(OBJDUMP) -d $< > $@

$(TARGET).elf: $(TARGET).o | docker-image-build
	@echo "Linking object file..."
	$(CC) $(ARCH) -o $@ $< -T link.ld -nostdlib -Wl,-Map,$(TARGET).map

$(TARGET).o: $(TARGET).s | docker-image-build
	@echo "Compiling assembly..."
	$(CC) $(ARCH) -c -o $@ $<

docker-image-build:
	@if [ -z "$(DOCKER_IMAGE_CHECK)" ]; then \
		echo "Docker image '$(IMAGE_NAME)' not found, building..."; \
		docker build -t $(IMAGE_NAME) $(TOOLCHAIN_DIR); \
	fi

clean:
	@echo "Cleaning up..."
	rm -f *.o *.elf *.bin *.hex *.asm *.map
	rm -f tohost_test/*.o tohost_test/*.elf tohost_test/*.bin tohost_test/*.hex tohost_test/*.asm tohost_test/*.map
