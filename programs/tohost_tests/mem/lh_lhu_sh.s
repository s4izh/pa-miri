.include "macros.inc"
.section .data
test_memory: .word 0
.global _start
.section .text
_start:
    la   s0, test_memory
    li   a1, 0xFFFF8765
    sh   a1, 0(s0)      # Store lower halfword 0x8765
    lh   a2, 0(s0)      # Load signed, should be sign-extended to 0xFFFF8765
    bne  a1, a2, fail_loop
    lhu  a3, 0(s0)      # Load unsigned, should be zero-extended to 0x00008765
    li   t0, 0x8765
    bne  a3, t0, fail_loop
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
