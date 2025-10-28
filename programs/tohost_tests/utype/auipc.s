.include "macros.inc"
.global _start
.section .text
_start:
    # Test Add Upper Immediate to PC
    # Result should be: PC of this instruction + (immediate << 12)
    # Here, immediate is 1, so we expect PC + 0x1000.
    auipc a0, 1
    
    # --- Manually construct the expected value ---
    # 1. Load the PC of the 'auipc' instruction (which is the same as _start)
    la   t0, _start
    
    # 2. Load the large immediate offset into a separate register,
    #    because 0x1000 is too big for a single ADDI.
    li   t1, 0x1000
    
    # 3. Add them together using a standard R-type ADD
    add  t0, t0, t1
    
    # Verify that the result from AUIPC matches our manually calculated address
    bne a0, t0, fail_loop
    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
