.include "macros.inc"

.section .data
.align 4
test_mem:  .word 0x00000000
test_mem2: .word 0x00000000

.section .text
.global _start

_start:
    la   s0, test_mem
    la   s1, test_mem2

    # =========================================================================
    # TEST 1: Simple Word Bypass (SW -> LW)
    # =========================================================================
    li   t0, 0xDEADBEEF
    sw   t0, 0(s0)
    lw   t1, 0(s0)          # Load should hit the Store Buffer
    bne  t0, t1, fail_1

    # =========================================================================
    # TEST 2: Partial Bypass - Word to Byte (SW -> LB/LBU)
    # Tests if your SB can extract the correct byte from a stored word
    # =========================================================================
    li   t0, 0x12348A7F     # 8A is negative if treated as signed byte
    sw   t0, 0(s0)
    
    lb   t1, 0(s0)          # Should be 0x7F (LSB)
    li   t2, 0x0000007F
    bne  t1, t2, fail_2
    
    lb   t1, 1(s0)          # Should be 0xFFFFFF8A (Sign extended!)
    li   t2, 0xFFFFFF8A
    bne  t1, t2, fail_2

    lbu  t1, 1(s0)          # Should be 0x0000008A (Zero extended)
    li   t2, 0x0000008A
    bne  t1, t2, fail_2

    # =========================================================================
    # TEST 3: Partial Bypass - Word to Halfword (SW -> LH)
    # =========================================================================
    li   t0, 0xCAFEFACE
    sw   t0, 0(s0)
    
    lh   t1, 2(s0)          # Load upper half: 0xCAFE
    li   t2, 0xFFFFCAFE     # Sign extended
    bne  t1, t2, fail_3

    # =========================================================================
    # TEST 4: "The Frankensword" - Multiple Small Stores -> One Big Load
    # Tests if SB can "merge" or if it stalls correctly
    # =========================================================================
    li   t2, 0x11
    sb   t2, 0(s0)
    li   t2, 0x22
    sb   t2, 1(s0)
    li   t2, 0x33
    sb   t2, 2(s0)
    li   t2, 0x44
    sb   t2, 3(s0)
    
    lw   t1, 0(s0)          # Should see 0x44332211
    li   t0, 0x44332211
    bne  t1, t0, fail_4

    # =========================================================================
    # TEST 5: Overlapping Write-After-Write (WAW)
    # Store a word, then "patch" one byte, then load
    # =========================================================================
    li   t0, 0xFFFFFFFF
    sw   t0, 0(s1)
    li   t1, 0x00
    sb   t1, 1(s1)          # Wipe out just the second byte
    
    lw   t2, 0(s1)          # Should be 0xFFFF00FF
    li   t3, 0xFFFF00FF
    bne  t2, t3, fail_5

    # =========================================================================
    # TEST 6: Zero-Cost Arbiter Stress (Back-to-back RAW)
    # This specifically tests if your 'ld_req_ready_o' can stay high 
    # while the Store Buffer is full.
    # =========================================================================
    li   t0, 0xAAAA5555
    sw   t0, 0(s0)          # Store 1
    sw   t0, 4(s0)          # Store 2 (SB filling up...)
    lw   a1, 0(s0)          # Load 1 (Bypass?)
    lw   a2, 4(s0)          # Load 2 (Bypass?)
    bne  a1, t0, fail_6
    bne  a2, t0, fail_6

    j pass_loop

# --- Failure Handlers ---
fail_1: li a0, 1; j fail_loop
fail_2: li a0, 2; j fail_loop
fail_3: li a0, 3; j fail_loop
fail_4: li a0, 4; j fail_loop
fail_5: li a0, 5; j fail_loop
fail_6: li a0, 6; j fail_loop

pass_loop:
    write_tohost_success
    j pass_loop

fail_loop:
    # a0 contains the test number that failed
    write_tohost_failure
    j fail_loop
