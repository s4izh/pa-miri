.include "macros.inc"
.global _start
.section .text
_start:
    # Test Set Less Than Immediate (Signed)
    li a1, -5
    slti a0, a1, 10 # (-5 < 10) is true
    li t0, 1
    bne a0, t0, fail_loop
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
