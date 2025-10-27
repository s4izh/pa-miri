# =============================================================================
# Minimal RISC-V Memory Test (SW and LW)
#
# Description:
# This program performs a single store word (sw) and load word (lw)
# operation to verify basic data memory functionality.
#
# Verification:
# - If the value loaded back from memory matches the original stored value,
#   the program will enter an infinite `pass_loop`.
# - If the values do not match, it will enter an infinite `fail_loop`.
# A testbench can check the final PC to determine the outcome.
# =============================================================================

.section .data
# Reserve a single word in memory to use for the test.
store_target: .word 0

.global _start
.section .text
_start:
    # 1. SETUP
    #   Load the address of our target memory location into s0 (base pointer).
    #   Load a known, non-zero value into a0 to be our test data.
    la   s0, store_target
    li   a0, 0xDEADBEEF      # The value we will store.

    # 2. EXECUTE STORE
    #   Store the value from register a0 into the memory location
    #   pointed to by register s0.
    sw   a0, 0(s0)

    # 3. EXECUTE LOAD
    #   Load the word from the memory location pointed to by s0
    #   back into a *different* register (a1) to ensure we are
    #   truly reading from memory.
    lw   a1, 0(s0)

    # 4. VERIFY
    #   Compare the original value (a0) with the loaded value (a1).
    #   If they are NOT equal, something went wrong. Branch to the fail_loop.
    bne  a0, a1, fail_loop

    # If the bne is not taken, it means a0 == a1, so the test has passed.
    # Fall through to the pass_loop.

pass_loop:
    li t0, 0
    sw t0, -4(zero)
    j pass_loop             # Success! Spin here forever.

fail_loop:
    li t0, 1
    sw t0, -4(zero)
    j fail_loop             # Failure! Spin here forever.
