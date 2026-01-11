.include "macros.inc"

.global _start
.section .text
_start:
    li t0, 10
    li t1, 20
    nop
    nop
    li t2, 0
    mul t2, t1, t0
    add t3, t2, t2
    beq zero, t3, fail_loop

pass_loop:
    write_tohost_success
    j pass_loop

fail_loop:
    write_tohost_failure
    j fail_loop
