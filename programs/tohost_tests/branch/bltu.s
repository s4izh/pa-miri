.include "macros.inc"
.global _start
.section .text
_start:
    li a1, -1; li a2, 10 # a1 is large unsigned, a2 is small unsigned
    bltu a2, a1, taken_ok # (10 < 0xFFFFFFFF) is true. Should be taken.
    j fail_loop
taken_ok:
    bltu a1, a2, fail_loop  # (0xFFFFFFFF < 10) is false. Should NOT be taken.
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
