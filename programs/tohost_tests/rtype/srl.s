.include "macros.inc"
.global _start
.section .text
_start:
    # Test Shift Right Logical
    li   a1, 0x80000000  # MSB is 1
    li   a2, 1
    srl  a0, a1, a2      # Expected: 0x40000000 (0 is shifted in)

    li   t0, 0x40000000
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
