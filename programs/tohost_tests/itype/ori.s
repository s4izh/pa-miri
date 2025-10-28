.include "macros.inc"
.global _start
.section .text
_start:
    li  a1, 0b1100
    ori a0, a1, 0b1010 # 12 | 10 = 14
    li  t0, 14
    bne a0, t0, fail_loop
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
