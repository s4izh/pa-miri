.include "macros.inc"

.section .data
.align 4

mem_loc_1: .word 0x00000000
.space 16
mem_loc_2: .word 0x00000000

.global _start
.section .text
_start:
    la s0, mem_loc_1
    la s1, mem_loc_2
    li t0, 0xDEADBEEF
    li t1, 0xCAFEBABE

    sw t0, 0(s0)
    sw t1, 0(s1)

    fence

    lw a0, 0(s0)
    lw a1, 0(s1)

    bne a0, t0, fail_loop
    bne a1, t1, fail_loop

    li t2, 0x12345678
    sw t2, 0(s0)
    lw a0, 0(s0)
    bne a0, t2, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop

fail_loop:
    write_tohost_failure
    j fail_loop
