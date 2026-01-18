.include "macros.inc"

.section .data
store_target0: .word 0
store_target1: .word 0
store_target2: .word 0

.global _start
.section .text
_start:
    la   s0, store_target0
    li   a0, 0xCAFEEFAC

    sb   a0, 0(s0)
    srli a0, a0, 4
    sb   a0, 1(s0)
    srli a0, a0, 4
    sb   a0, 2(s0)
    srli a0, a0, 4
    sb   a0, 3(s0)
    srli a0, a0, 4

    la   s0, store_target1
    li   a0, 0xCAFEEFAC

    sh   a0, 0(s0)
    srli a0, a0, 8
    sh   a0, 2(s0)
    srli a0, a0, 8

    la   s0, store_target2
    li   a0, 0xCAFEEFAC

    sw   a0, 0(s0)

    la   s0, store_target0
    lw   t0, 0(s0)
    lw   t1, 4(s0)
    lw   t2, 8(s0)
    sub  t0, t2, t0
    sub  t1, t2, t1
    sub  t0, t0, t1
    bne  zero, t3, fail_loop

    lb t0, 0(s0)
    lh t1, 6(s0)

    # Misaligned exception (any of the instructions should trigger it)
    lh t0, 1(s0)
    lh t0, 3(s0)
    lw t0, 1(s0)
    lw t0, 2(s0)
    lw t0, 3(s0)

fail_loop:
    write_tohost_failure
    j fail_loop

pass_loop:
    write_tohost_success
    j pass_loop

.global _trap_handler
.section .text._trap_handler
_trap_handler:
    j pass_loop
