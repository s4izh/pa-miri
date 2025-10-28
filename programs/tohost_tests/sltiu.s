.include "macros.inc"
.global _start
.section .text
_start:
    # Test Set Less Than Immediate Unsigned
    li   a1, 100

    # Case 1: 100 < 200U should be true (1)
    sltiu a0, a1, 200
    li    t0, 1
    bne   a0, t0, fail_loop

    # Case 2: 100 < -1U (a large number) should be true (1)
    sltiu a0, a1, -1
    li    t0, 1
    bne   a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
