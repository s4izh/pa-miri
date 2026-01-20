.include "macros.inc"
.global _start
.section .text
.align 4
_start:
    la   t0, custom_handler

    csrw mtvec, t0

    csrr t1, mtvec
    bne  t0, t1, fail_loop

    # Execute Environment Call. This raises an ilegal instruction exception (unimplemented)
    # ecall

    ecall

    # If the processor ignores the trap or falls through, we land here.
    j fail_loop

.align 4

custom_handler:
    csrr t2, mcause
    # li   t3, 11
    li t3, 0
    bne  t2, t3, fail_loop
    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop

fail_loop:
    write_tohost_failure
    j fail_loop
