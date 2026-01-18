.include "macros.inc"

.section .data
.align 4
store_target0: .word 0
store_target1: .word 0
store_target2: .word 0

.global _start
.section .text
_start:
    # ---------------------------------------------------
    # 1. Store BYTES to construct 0xCAFEEFAC
    # ---------------------------------------------------
    la   s0, store_target0
    li   a0, 0xCAFEEFAC

    sb   a0, 0(s0)      # Store LSB (0xAC)
    srli a0, a0, 8      # Shift 8 bits
    sb   a0, 1(s0)      # Store next byte (0xEF)
    srli a0, a0, 8
    sb   a0, 2(s0)      # Store next byte (0xFE)
    srli a0, a0, 8
    sb   a0, 3(s0)      # Store MSB (0xCA)

    # ---------------------------------------------------
    # 2. Store HALFWORDS to construct 0xCAFEEFAC
    # ---------------------------------------------------
    la   s0, store_target1
    li   a0, 0xCAFEEFAC # Reload a0 (it was destroyed by shifts)

    sh   a0, 0(s0)      # Store lower 16 bits (0xEFAC)
    srli a0, a0, 16     # Shift 16 bits
    sh   a0, 2(s0)      # Store upper 16 bits (0xCAFE)

    # ---------------------------------------------------
    # 3. Store WORD directly
    # ---------------------------------------------------
    la   s0, store_target2
    li   a0, 0xCAFEEFAC
    sw   a0, 0(s0)      # Store full word

    # ---------------------------------------------------
    # 4. VERIFICATION
    # ---------------------------------------------------
    la   s0, store_target0
    
    lw   t0, 0(s0)      # Load from Bytes target
    lw   t1, 4(s0)      # Load from Halfwords target (offset 4)
    lw   t2, 8(s0)      # Load from Word target (offset 8)

    # Check Byte construction vs Word construction
    bne  t0, t2, fail_loop

    # Check Halfword construction vs Word construction
    bne  t1, t2, fail_loop

    # ---------------------------------------------------
    # 5. MISALIGNED EXCEPTION TEST
    # ---------------------------------------------------
    # The processor MUST trap on this instruction.
    # - If it traps: It jumps to _trap_handler -> pass_loop. (SUCCESS)
    # - If it ignores alignment: It executes the next line -> fail_loop. (FAILURE)
    
    lh   t0, 1(s0)      # Misaligned load (odd address)

    # If we are here, the CPU failed to trap
    j    fail_loop

fail_loop:
    write_tohost_failure
    j fail_loop

pass_loop:
    write_tohost_success
    j pass_loop

.global _trap_handler
.section .text._trap_handler
_trap_handler:
    # We assume any trap here is the expected misaligned exception
    j pass_loop
