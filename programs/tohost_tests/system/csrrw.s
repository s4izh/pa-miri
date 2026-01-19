.include "macros.inc"
.section .data
test_memory: .word 0
.global _start
.section .text
_start:
    li t0, 0x2000
    csrw mtvec, t0
    csrr t1, mtvec
    div a0, t0, zero
    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a3, 1
    addi a3, a3, 1
    addi a4, a4, 1
    beq t0, t1, fail_loop
fail_loop:
    write_tohost_failure
    j fail_loop
pass_loop:
    write_tohost_success
    j pass_loop

.global _trap_handler
.section .text._trap_handler
_trap_handler:
    csrr t1, mepc
    j pass_loop
