# programs/tohost_tests/bypass/bypass_mix.s
.include "macros.inc"
.global _start
.section .text
_start:
    # Setup: We want x1 to be written by two consecutive instructions
    
    li x1, 10       # Cycle T:   Enters DEC
                    # Cycle T+1: Enters EX
                    # Cycle T+2: Enters MEM (Older value)

    li x1, 20       # Cycle T+1: Enters DEC
                    # Cycle T+2: Enters EX  (Newer value)

    add x2, x1, zero # Cycle T+2: Enters DEC. Needs x1.
    
    # Logic check:
    # In Cycle T+2:
    #   Stage 4 (MEM) has x1 = 10
    #   Stage 3 (EX)  has x1 = 20
    # Fwd unit sees both match. It MUST pick Stage 3 (Youngest).
    
    li t0, 20
    bne x2, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
