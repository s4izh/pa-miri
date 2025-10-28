.include "macros.inc"
.section .data
test_memory: .word 0
.global _start
.section .text
_start:
    la   s0, test_memory
    li   a1, 0xFFFFFF85
    sb   a1, 0(s0)      # Store lower byte 0x85
    lb   a2, 0(s0)      # Load signed, should be sign-extended to 0xFFFFFF85
    bne  a1, a2, fail_loop
    lbu  a3, 0(s0)      # Load unsigned, should be zero-extended to 0x00000085
    li   t0, 0x85
    bne  a3, t0, fail_loop
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
