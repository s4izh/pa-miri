.include "macros.inc"

.global _start
.section .text
_start:
    li t0, 10
    li t1, 33
    mulhsu t2, t0, t1
    li t0, -10
    li t1, 33
    mulhsu t2, t0, t1
    li t0, 10
    li t1, -33
    mulhsu t2, t0, t1
    li t0, -10
    li t1, -33
    mulhsu t2, t0, t1
    li t0, 0
    li t1, -33
    mulhsu t2, t0, t1
    li t0, 10
    li t1, 0
    mulhsu t2, t0, t1
pass_loop:
    write_tohost_success
    j pass_loop
