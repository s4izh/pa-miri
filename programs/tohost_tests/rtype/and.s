.include "macros.inc"
.global _start
.section .text
_start:
    # Test AND
    li   a1, 0b1100  # 12
    li   a2, 0b1010  # 10
    and  a0, a1, a2      # Expected: 0b1000 (8)

    li   t0, 8
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
