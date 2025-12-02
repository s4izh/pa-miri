.include "macros.inc"
.section .data
    test_val: .word 0xDEADBEEF
    test_val2: .word 0x00000000

.global _start
.section .text
_start:
    la  s0, test_val
    lw  x1, 0(s0)
    sw  x1, 4(s0) # Should bypass M->E

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
