.include "macros.inc"

.global _start
.section .text
_start:
# =========================================================================
# TEST 1: Saturation and Misprediction Recovery
# =========================================================================
# We will loop 20 times.
# - Iterations 1-2: Predictor learns (Weak Taken -> Strong Taken).
# - Iterations 3-19: Predictor correctly predicts Taken.
# - Iteration 20: Predictor predicts Taken (Strong), but actual is Not Taken.
#
# This LAST step triggers the flush. If the NOP injection logic is wrong,
# the CPU will infinite loop on the flush here.
# =========================================================================
    li  s0, 0       # Loop counter
    li  s1, 20      # Limit
    li  s2, 0       # Accumulator

saturation_loop:
    addi s2, s2, 1 # Do some work
    addi s0, s0, 1 # Increment counter
    bne s0, s1, saturation_loop # Branch back if s0 != 20

# If we get here, the misprediction flush worked!
# Check Accumulator
    li  t0, 20
    bne s2, t0, fail_loop

# =========================================================================
# TEST 2: Ping-Pong (Forward and Backward jumps)
# Tests BTB target caching
# =========================================================================
    li  s2, 0

# Jump forward
    j   step_1

step_2:
    addi s2, s2, 10 # s2 += 10 (Should be 11)
    j step_3

step_1:
    addi s2, s2, 1 # s2 += 1
    j step_2 # Jump backward (physically lower address if aligned nearby)

step_3:
    li t0, 11
    bne s2, t0, fail_loop

# =========================================================================
# TEST 3: JALR Indirection
# Many simple predictors struggle with JALR if they assume JAL/Branch format
# =========================================================================
    la  t0, jalr_target
    jalr ra, t0, 0

# Should return here
    j   check_final

jalr_target:
    addi s2, s2, 1 # s2 += 1 (Should be 12)
    jalr zero, ra, 0 # Return

check_final:
    li t0, 12
    bne s2, t0, fail_loop

pass_loop:
    write_tohost_success
    j pass_loop

fail_loop:
    write_tohost_failure
    j fail_loop
