.include "macros.inc"
.global _start
.section .text
_start:
    # Test Load Upper Immediate (lui)
    # Loads the 20-bit immediate into the upper 20 bits of the register.
    lui a0, 0xABCDE      # Expected: a0 = 0xABCDE000

    li  t0, 0xABCDE000
    bne a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
