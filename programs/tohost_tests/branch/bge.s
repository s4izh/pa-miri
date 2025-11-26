.include "macros.inc"
.global _start
.section .text
_start:
    li a1, 10 # mantain dependency on a1 for bge
    li a2, 5
    li a3, 10
    bge a1, a2, taken_1 # (10 >= 5) is true. Should be taken.
    j fail_loop
taken_1:
    bge a1, a3, taken_2 # (10 >= 10) is true. Should be taken.
    j fail_loop
taken_2:
    bge a2, a1, fail_loop # (5 >= 10) is false. Should NOT be taken.
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
