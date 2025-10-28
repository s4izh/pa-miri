.include "macros.inc"
.global _start
.section .text
_start:
    li   a1, 7
    slli a0, a1, 2 # 7 << 2 = 28
    li   t0, 28
    bne  a0, t0, fail_loop
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
