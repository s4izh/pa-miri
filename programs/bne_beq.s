# =============================================================================
# Minimal RISC-V Branch Test (BEQ and BNE)
#
# Description:
# This program tests a 'taken' branch and a 'not-taken' (fall-through)
# branch to verify conditional logic.
#
# Verification:
# - The program uses a register (a0) as a success counter. If both tests
#   behave correctly, the counter will be incremented twice.
# - A final check verifies the counter's value. If correct, the program
#   enters a `pass_loop`; otherwise, it enters a `fail_loop`.
# =============================================================================

.global _start
.section .text
_start:
    # 1. SETUP
    #   - a0 will be our success counter, initialized to 0.
    #   - a1 and a2 will hold values for comparison.
    li   a0, 0           # Success counter
    li   a1, 5           # Value A
    li   a2, 10          # Value B

    # 2. TEST 1: BEQ (should NOT be taken)
    #   Compare a1 (5) and a2 (10). They are not equal.
    #   The 'beq' should fall through. If it incorrectly takes the branch,
    #   it will jump straight to the fail_loop.
    beq  a1, a2, fail_loop

    # If we get here, the fall-through was correct. Increment success counter.
    addi a0, a0, 1       # Counter is now 1.

    # 3. TEST 2: BNE (should BE taken)
    #   Compare a1 (5) and a2 (10). They are not equal.
    #   The 'bne' should be taken. If it incorrectly falls through,
    #   the next instruction will jump to the fail_loop.
    bne  a1, a2, bne_was_taken
    j    fail_loop       # This line should be skipped.

bne_was_taken:
    # If we get here, the taken branch was correct. Increment success counter.
    addi a0, a0, 1       # Counter is now 2.

    # 4. VERIFY
    #   After two successful tests, our counter in a0 should be 2.
    #   Compare a0 to the expected value 2. If they are not equal,
    #   something went wrong.
    li   t0, 2           # Expected final value
    bne  a0, t0, fail_loop

    # If the final check passes, fall through to the success loop.

pass_loop:
    li t0, 0
    sw t0, -4(zero)
    j pass_loop             # Success! Spin here forever.

fail_loop:
    li t0, 1
    sw t0, -4(zero)
    j fail_loop             # Failure! Spin here forever.
