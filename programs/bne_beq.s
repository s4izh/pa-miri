.include "macros.inc"

.global _start
.section .text

_start:
    li   a0, 0           # success counter
    li   a1, 5
    li   a2, 10

    beq  a1, a2, fail_loop

    addi a0, a0, 1       # counter = 1

    bne  a1, a2, bne_was_taken
    j    fail_loop

bne_was_taken:
    addi a0, a0, 1       # counter = 2

    li   t0, 2           # counter should be 2 here
    bne  a0, t0, fail_loop

pass_loop:
    li   t0, 0
    write_tohost t0
    j    pass_loop

fail_loop:
    li   t0, 1
    write_tohost t0
    j    fail_loop
