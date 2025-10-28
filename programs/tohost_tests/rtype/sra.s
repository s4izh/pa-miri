.include "macros.inc"
.global _start
.section .text
_start:
    # Test Shift Right Arithmetic
    li   a1, -16         # Binary: ...1111111111110000
    li   a2, 2
    sra  a0, a1, a2      # Expected: -4 (Binary: ...1111111111111100)

    li   t0, -4
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
