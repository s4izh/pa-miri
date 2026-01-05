.include "macros.inc"

.global _start
.section .text
_start:
    li t0, 10
    li t1, 33
    divu t2, t1, t0
    li t0, -10
    li t1, 33
    divu t2, t0, t1
    li t0, 10
    li t1, -33
    divu t2, t0, t1
    li t0, -10
    li t1, -33
    divu t2, t0, t1
    li t0, 0
    li t1, -33
    divu t2, t0, t1
    li t0, 10
    li t1, 0
    divu t2, t0, t1
fail_loop:
    write_tohost_failure
    j fail_loop

.global _trap_handler
.section .text._trap_handler
_trap_handler:
pass_loop:
    write_tohost_success
    j pass_loop
