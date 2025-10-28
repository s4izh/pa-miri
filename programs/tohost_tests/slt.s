.include "macros.inc"
.global _start
.section .text
_start:
    # Test Set Less Than (Signed)
    li   a1, -10
    li   a2, 5

    # Case 1: -10 < 5 should be true (1)
    slt  a0, a1, a2
    li   t0, 1
    bne  a0, t0, fail_loop

    # Case 2: 5 < -10 should be false (0)
    slt  a0, a2, a1
    bne  a0, zero, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
