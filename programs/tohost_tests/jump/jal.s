.include "macros.inc"
.global _start
.section .text
_start:
    # Test Jump and Link
    # It should jump to the target, storing PC+4 in the link register (ra).
    jal ra, target_function
    
    # This line should be SKIPPED. If execution falls through, it's a failure.
    j fail_loop 

target_function:
    # If we successfully jumped here, the JAL instruction worked.
    # The value of 'ra' should be the address of the 'j fail_loop' line.
    # Now, we use jalr to return to the correct place to pass the test.
    addi ra, ra, 4 # Adjust return address to point to 'pass_marker'
    jalr zero, ra, 0

pass_marker:
    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
