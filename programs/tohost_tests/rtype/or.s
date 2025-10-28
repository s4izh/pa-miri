.include "macros.inc"
.global _start
.section .text
_start:
    # Test OR
    li   a1, 0b1100  # 12
    li   a2, 0b1010  # 10
    or   a0, a1, a2      # Expected: 0b1110 (14)

    li   t0, 14
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
