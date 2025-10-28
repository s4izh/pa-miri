.include "macros.inc"
.section .data
test_memory: .word 0
.global _start
.section .text
_start:
    la   s0, test_memory
    li   a1, 0x12345678
    sw   a1, 0(s0)
    lw   a2, 0(s0)
    bne  a1, a2, fail_loop
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
