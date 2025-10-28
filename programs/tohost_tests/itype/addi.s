.include "macros.inc"
.global _start
.section .text
_start:
    # Test ADD Immediate
    li   a1, 50
    addi a0, a1, 100     # Expected: a0 = 150

    li   t0, 150
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
