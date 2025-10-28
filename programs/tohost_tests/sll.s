.include "macros.inc"
.global _start
.section .text
_start:
    # Test Shift Left Logical
    li   a1, 5           # 0b0101
    li   a2, 3
    sll  a0, a1, a2      # Expected: 5 << 3 = 40 (0b101000)

    li   t0, 40
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
