.include "macros.inc"

.global _start
.section .text
_start:
    li   a1, 10
    li   a2, 5

    add  a0, a1, a2

    li   t0, 15
    bne  a0, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
