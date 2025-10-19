# This program tests all 6 outcomes of the beq, blt, and bgt instructions.
# Register r10 is used to track the test results.
# If all tests pass, the final value in r10 will be 6.

# --- TEST 1: BEQ (Branch is TAKEN) ---
# SETUP: r1 = 10, r2 = 10. Condition (r1 == r2) is TRUE.
# PC=0:
li 10 -> r1
# PC=1:
li 10 -> r2
# PC=2: BRANCH. If equal, jump 2 instructions to the TAKEN path. Target PC = 2 + 2 = 4.
beq r1, r2, 2
# PC=3: FALL-THROUGH (should be skipped). Jump to next test. Target PC = 3 + 2 = 5.
beq r0, r0, 2
# PC=4: TAKEN_PATH. Set result register to 1.
li 1 -> r10

# --- TEST 2: BEQ (Branch is NOT TAKEN) ---
# SETUP: r1 = 10, r2 = 20. Condition (r1 == r2) is FALSE.
# PC=5:
li 20 -> r2
# PC=6: BRANCH. If equal, jump 2 instructions. This branch should NOT be taken.
beq r1, r2, 2
# PC=7: FALL-THROUGH (should be executed). Set result register to 2.
li 2 -> r10
# PC=8: Jump to next test. Target PC = 8 + 1 = 9.
beq r0, r0, 1
# PC=9: TAKEN_PATH (should be skipped).

# --- TEST 3: BLT (Branch is TAKEN) ---
# SETUP: r1 = 10, r2 = 20. Condition (r1 < r2) is TRUE.
# PC=9: BRANCH. If less than, jump 2 instructions to the TAKEN path. Target PC = 9 + 2 = 11.
blt r1, r2, 2
# PC=10: FALL-THROUGH (should be skipped). Jump to next test. Target PC = 10 + 2 = 12.
beq r0, r0, 2
# PC=11: TAKEN_PATH. Set result register to 3.
li 3 -> r10

# --- TEST 4: BLT (Branch is NOT TAKEN) ---
# SETUP: r1 = 20, r2 = 10. Condition (r1 < r2) is FALSE.
# PC=12:
li 10 -> r2
# PC=13:
li 20 -> r1
# PC=14: BRANCH. If less than, jump 2 instructions. This branch should NOT be taken.
blt r1, r2, 2
# PC=15: FALL-THROUGH (should be executed). Set result register to 4.
li 4 -> r10
# PC=16: Jump to next test. Target PC = 16 + 1 = 17.
beq r0, r0, 1
# PC=17: TAKEN_PATH (should be skipped).

# --- TEST 5: BGT (Branch is TAKEN) ---
# SETUP: r1 = 20, r2 = 10. Condition (r1 > r2) is TRUE.
# PC=17: BRANCH. If greater than, jump 2 instructions to TAKEN path. Target PC = 17 + 2 = 19.
bgt r1, r2, 2
# PC=18: FALL-THROUGH (should be skipped). Jump to next test. Target PC = 18 + 2 = 20.
beq r0, r0, 2
# PC=19: TAKEN_PATH. Set result register to 5.
li 5 -> r10

# --- TEST 6: BGT (Branch is NOT TAKEN) ---
# SETUP: r1 = 10, r2 = 20. Condition (r1 > r2) is FALSE.
# PC=20:
li 20 -> r2
# PC=21:
li 10 -> r1
# PC=22: BRANCH. If greater than, jump 2 instructions. This branch should NOT be taken.
bgt r1, r2, 2
# PC=23: FALL-THROUGH (should be executed). Set result register to 6.
li 6 -> r10
# PC=24: Jump to next test. Target PC = 24 + 1 = 25.
beq r0, r0, 1
# PC=25: TAKEN_PATH (should be skipped).

# --- HALT ---
# PC=25: Unconditionally jump to self (offset = 0). This effectively halts the CPU.
beq r10, r10, 0
