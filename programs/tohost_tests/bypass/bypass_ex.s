.include "macros.inc"
.global _start
.section .text
_start:
    # 1. Test RS1 Forwarding from EX
    li  x1, 10          # In EX stage when next instr is in DEC
    addi x2, x1, 5      # Needs x1 immediately. Should get 10.
                        # x2 = 15

    li  t0, 15
    bne x2, t0, fail_loop

    # 2. Test RS2 Forwarding from EX
    li  x3, 20          # In EX stage
    add x4, zero, x3    # RS2 is x3. Should get 20.
                        # x4 = 20

    li  t0, 20
    bne x4, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
