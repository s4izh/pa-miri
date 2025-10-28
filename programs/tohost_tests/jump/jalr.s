.include "macros.inc"
.global _start
.section .text
_start:
    # Test Jump and Link Register (jalr)
    # Load the address of the target label
    la   t1, target_label

    # Jump to the target, storing the return address (the next instruction) in ra
    jalr ra, t1, 0

    # If we successfully return, this code will execute.
    # We check a flag set by the target function.
    li t0, 1
    bne a0, t0, fail_loop # a0 should have been set to 1 in the target
    j pass_loop

    # This code should never be reached
    j fail_loop

target_label:
    # Set a flag to indicate we reached the target
    li a0, 1
    # Jump back to the return address stored in ra
    jalr zero, ra, 0

pass_loop:
    write_tohost_success
    j    pass_loop

fail_loop:
    write_tohost_failure
    j    fail_loop
