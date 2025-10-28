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
    addi ra, ra, 12 # add 12 to ra so we jump 3 instructions ahead
                    # ra is pointing at j fail_loop instruction
                    # so we need to skip the next 3 instructions to reach pass_marker
    jalr zero, ra, 0

pass_marker:
    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
