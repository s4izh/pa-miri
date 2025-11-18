.include "macros.inc"
.global _start
.section .text
_start:
    li a1, 10
    li a2, 10
    li a3, 20
    beq a1, a2, taken_ok  # Should be taken
    j fail_loop
taken_ok:
    beq a1, a3, fail_loop   # Should NOT be taken
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
