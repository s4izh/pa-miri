# =============================================================================
# RISC-V Comprehensive Processor Test Program
#
# Description:
# This program tests a wide range of RV32I instructions to verify the
# functionality of a RISC-V processor core.
#
# Verification Method:
# The program executes a series of tests. For each test, it stores the
# result in a dedicated memory location in the .data section. After running
# the simulation, the memory contents can be examined to check if they
# match the expected values (provided in comments).
#
# =============================================================================

.section .data
# Define memory locations to store the results of our tests.
# Initialize them to 0. The expected value after the test is in a comment.
result_add:     .word 0   # Expected: 15
result_sub:     .word 0   # Expected: -5 (0xFFFFFFFB)
result_sll:     .word 0   # Expected: 40
result_slt:     .word 0   # Expected: 0
result_sltu:    .word 0   # Expected: 1
result_xor:     .word 0   # Expected: 15
result_srl:     .word 0   # Expected: 2
result_sra:     .word 0   # Expected: -3 (0xFFFFFFFD)
result_or:      .word 0   # Expected: 15
result_and:     .word 0   # Expected: 0

result_addi:    .word 0   # Expected: 100
result_slti:    .word 0   # Expected: 1
result_sltiu:   .word 0   # Expected: 1
result_xori:    .word 0   # Expected: 0xFFFF (65535)
result_ori:     .word 0   # Expected: 0xFFFF (65535)
result_andi:    .word 0   # Expected: 0x0F0F (3855)
result_slli:    .word 0   # Expected: 0x8000 (32768)
result_srli:    .word 0   # Expected: 0x000F (15)
result_srai:    .word 0   # Expected: 0xFFFFFFFF (-1)

result_lw:      .word 0   # Expected: 0xDEADBEEF
result_lh:      .word 0   # Expected: 0xFFFFBEEF (-16657)
result_lhu:     .word 0   # Expected: 0x0000BEEF (48879)
result_lb:      .word 0   # Expected: 0xFFFFFFEF (-17)
result_lbu:     .word 0   # Expected: 0x000000EF (239)
result_sw:      .word 0   # Expected: 0x12345678 (verified by loading it back)

result_beq_taken: .word 0 # Expected: 1 (taken)
result_beq_fall:  .word 0 # Expected: 0 (not taken)
result_bne_taken: .word 0 # Expected: 1 (taken)
result_bne_fall:  .word 0 # Expected: 0 (not taken)
result_blt_taken: .word 0 # Expected: 1 (taken)
result_bge_taken: .word 0 # Expected: 1 (taken)
result_bltu_taken:.word 0 # Expected: 1 (taken)

result_jal:     .word 0   # Expected: address of instruction after jal
result_jalr:    .word 0   # Expected: address of jalr_target label
result_lui:     .word 0   # Expected: 0xABCDE000
result_auipc:   .word 0   # Expected: (addr of auipc) + 0x00001000

# Data for load/store tests
mem_data_word:  .word 0xDEADBEEF
mem_data_half:  .half 0xBEEF
mem_data_byte:  .byte 0xEF
store_target:   .word 0 # A place to write to

.global _start
.section .text
_start:
    # Use s0 as a pointer to the results section in memory
    la s0, result_add

# =============================================================================
# R-Type Instruction Tests (Register-Register)
# =============================================================================
    li  a0, 5
    li  a1, 10
    li  a2, -10

    add a3, a0, a1      # 5 + 10 = 15
    sw  a3, 0(s0)
    sub a3, a0, a1      # 5 - 10 = -5
    sw  a3, 4(s0)
    sll a3, a0, 3       # 5 << 3 = 40
    sw  a3, 8(s0)
    slt a3, a1, a0      # 10 < 5 ? No (signed) -> 0
    sw  a3, 12(s0)
    sltu a3, a2, a0     # -10 < 5 ? Yes (unsigned, -10 is a large pos number) -> 1
    sw  a3, 16(s0)
    xor a3, a0, a1      # 0101 ^ 1010 = 1111 (15)
    sw  a3, 20(s0)
    srl a3, a1, 2       # 10 >> 2 = 2
    sw  a3, 24(s0)
    sra a3, a2, 2       # -10 >> 2 = -3 (arithmetic shift)
    sw  a3, 28(s0)
    or  a3, a0, a1      # 0101 | 1010 = 1111 (15)
    sw  a3, 32(s0)
    and a3, a0, a1      # 0101 & 1010 = 0000 (0)
    sw  a3, 36(s0)

# =============================================================================
# I-Type Instruction Tests (Register-Immediate)
# =============================================================================
    addi a0, zero, 100  # 0 + 100 = 100
    sw   a0, 40(s0)
    slti a0, zero, 1    # 0 < 1 ? Yes -> 1
    sw   a0, 44(s0)
    sltiu a0, zero, -1  # 0 < -1 (unsigned) ? Yes -> 1
    sw   a0, 48(s0)
    li   a1, 0xF0F0
    # The immediate 0x0F0F is too large for I-type instructions.
    # So, we load it into a temporary register (t0) first.
    li   t0, 0x0F0F

    # Now use the R-type versions of the instructions
    xor a0, a1, t0      # F0F0 ^ 0F0F = FFFF
    sw   a0, 52(s0)
    or  a0, a1, t0      # F0F0 | 0F0F = FFFF
    sw   a0, 56(s0)
    and a0, a1, t0      # F0F0 & 0F0F = 0F0F
    sw   a0, 60(s0)
    li   a1, 1
    slli a0, a1, 15     # 1 << 15 = 0x8000
    sw   a0, 64(s0)
    li   a1, 0xF0
    srli a0, a1, 4      # 0xF0 >> 4 = 0x0F (logical)
    sw   a0, 68(s0)
    li   a1, -16
    srai a0, a1, 4      # -16 >> 4 = -1 (arithmetic)
    sw   a0, 72(s0)

# =============================================================================
# Memory Instruction Tests (Load/Store)
# =============================================================================

    la a0, mem_data_word
    lw a1, 0(a0)        # Load 0xDEADBEEF
    sw a1, 76(s0)
    la a0, mem_data_half
    ; lh a1, 0(a0)        # Load 0xBEEF (sign extended)
    ; sw a1, 80(s0)
    ; lhu a1, 0(a0)       # Load 0xBEEF (zero extended)
    ; sw a1, 84(s0)
    ; la a0, mem_data_byte
    ; lb a1, 0(a0)        # Load 0xEF (sign extended)
    ; sw a1, 88(s0)
    ; lbu a1, 0(a0)       # Load 0xEF (zero extended)
    ; sw a1, 92(s0)

    # Test store by writing and then loading back
    la a0, store_target
    li a1, 0x12345678
    sw a1, 0(a0)
    lw a2, 0(a0)        # Load it back to verify
    sw a2, 96(s0)

# =============================================================================
# Branch Instruction Tests
# =============================================================================
    li a0, 5
    li a1, 5
    li a2, 10
    li a3, -5

    # Test BEQ
    beq a0, a1, beq_taken_target  # Should be taken
    sw zero, 100(s0)              # Fall-through writes 0
    j beq_fall_test
beq_taken_target:
    li t0, 1
    sw t0, 100(s0)                # Taken path writes 1
beq_fall_test:
    beq a0, a2, beq_fall_target   # Should NOT be taken
    sw zero, 104(s0)              # Fall-through writes 0
    j bne_taken_test
beq_fall_target:
    li t0, 1
    sw t0, 104(s0)                # This path should not be executed

    # Test BNE
bne_taken_test:
    bne a0, a2, bne_taken_target  # Should be taken
    sw zero, 108(s0)
    j bne_fall_test
bne_taken_target:
    li t0, 1
    sw t0, 108(s0)
bne_fall_test:
    bne a0, a1, bne_fall_target   # Should NOT be taken
    sw zero, 112(s0)
    j blt_taken_test
bne_fall_target:
    li t0, 1
    sw t0, 112(s0)

    # Test BLT
blt_taken_test:
    blt a3, a0, blt_taken_target  # -5 < 5? Yes, should be taken
    sw zero, 116(s0)
    j bge_taken_test
blt_taken_target:
    li t0, 1
    sw t0, 116(s0)

    # Test BGE
bge_taken_test:
    bge a2, a1, bge_taken_target  # 10 >= 5? Yes, should be taken
    sw zero, 120(s0)
    j bltu_taken_test
bge_taken_target:
    li t0, 1
    sw t0, 120(s0)

    # Test BLTU
bltu_taken_test:
    bltu a0, a3, bltu_taken_target # 5 < -5 (unsigned)? Yes, should be taken
    sw zero, 124(s0)
    j jump_tests
bltu_taken_target:
    li t0, 1
    sw t0, 124(s0)

# =============================================================================
# Jump Instruction Tests (JAL, JALR)
# =============================================================================
jump_tests:
    jal ra, jal_target  # Jump and link to target
    # Instruction after jal - its address should be in ra
jal_return:
    # Now test JALR to jump to the address we stored
    la   t0, jalr_target
    jalr ra, t0, 0      # Jump to jalr_target
    # This part should be skipped
    j done # Should not be reached
jalr_return:

jal_target:
    sw ra, 128(s0)      # Store the return address
    jalr zero, ra, 0    # Return from JAL (jumps to jal_return)

jalr_target:
    la t1, jalr_target
    sw t1, 132(s0)      # Store the target address to prove we got here
    jalr zero, ra, 0    # Return from JALR (jumps to jalr_return)

# =============================================================================
# U-Type Instruction Tests (LUI, AUIPC)
# =============================================================================
    lui a0, 0xABCDE     # Load 0xABCDE into upper 20 bits, a0 = 0xABCDE000
    sw  a0, 136(s0)

    auipc a0, 0x1       # a0 = PC + 0x1000
    sw    a0, 140(s0)   # Store result

# =============================================================================
# Exception Test (Optional)
# Uncommenting this will test the exception handling of your core.
# On a simple core, it might just halt.
# =============================================================================
    # ecall

# =============================================================================
# Test Finalization: Communicate with Testbench
#
# This section writes key information to fixed memory locations so the
# testbench can verify the results without needing objdump.
# =============================================================================
finalization:
    # Define the fixed addresses for communication (the "ABI")
    .equ HALT_ADDR,             0x10001FFC  # Address for the halt signature
    .equ RESULTS_BASE_PTR_ADDR, 0x10001FF8  # Address to store the results' base pointer

    # Load the base address of the results section into a register
    la   t0, result_add
    # Load the address where we will store this pointer
    li   t1, RESULTS_BASE_PTR_ADDR
    # Store the results' base address (from t0) into the fixed location
    sw   t0, 0(t1)

    # Signal to the testbench that the test is complete by writing
    # a magic number to the fixed HALT_ADDR.
    li   t0, 0xBAADF00D      # Magic "test finished" signature
    li   t1, HALT_ADDR
    sw   t0, 0(t1)

# =============================================================================
# End of Test - Infinite Loop
# The simulation can be stopped here and memory inspected.
# =============================================================================
done:
    j done
