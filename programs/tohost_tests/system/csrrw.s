.include "macros.inc"
.section .data
test_memory: .word 0
.global _start
.section .text
_start:
    li t0, 0x2000
    csrw mtvec, t0
    csrr t1, mtvec
    beq t0, t1, pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
pass_loop:
    write_tohost_success
    j pass_loop

.global _trap_handler
.section .text._trap_handler
_trap_handler:
    j fail_loop
