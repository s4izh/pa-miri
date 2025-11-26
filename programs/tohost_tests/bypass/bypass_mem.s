.include "macros.inc"
.global _start
.section .text
_start:
    # 1. Test RS1 Forwarding from MEM
    li  x1, 0xAA
    nop                 # x1 moves to MEM stage
    addi x2, x1, 0      # x2 needs x1. Should grab from MEM (not WB).
    
    li  t0, 0xAA
    bne x2, t0, fail_loop

    # 2. Test RS2 Forwarding from MEM
    li  x3, 0xBB
    nop                 # x3 moves to MEM stage
    add x4, zero, x3    # RS2 is x3. Should grab from MEM.

    li  t0, 0xBB
    bne x4, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
