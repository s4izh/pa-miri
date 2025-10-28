.include "macros.inc"
.global _start
.section .text
_start:
    # Test Branch Not Equal (bne)
    li a1, 5
    li a2, 10
    li a3, 5

    # Case 1: 5 != 10. Branch should be TAKEN.
    bne a1, a2, taken_path
    j fail_loop # Should not get here

taken_path:
    # Case 2: 5 != 5. Branch should NOT be taken.
    bne a1, a3, fail_loop
    j pass_loop # Should fall through to here

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
