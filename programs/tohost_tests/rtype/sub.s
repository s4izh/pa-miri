.include "macros.inc"
.global _start
.section .text
_start:
    # Test SUB
    li   a1, 100
    li   a2, 42
    sub  a0, a1, a2      # Expected: a0 = 58

    li   t0, 58
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
