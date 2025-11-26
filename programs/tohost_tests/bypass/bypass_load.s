.include "macros.inc"
.section .data
    test_val: .word 0xDEADBEEF

.global _start
.section .text
_start:
    la  s0, test_val
    
    # Load 0xDEADBEEF into x1
    lw  x1, 0(s0)       
    
    # HAZARD! 
    # x1 is not ready in EX stage. 
    # CPU must stall.
    # Then bypass x1 from MEM stage (which holds the loaded data).
    addi x2, x1, 1      # x2 = 0xDEADBEEF + 1 = 0xDEADBEF0

    li  t0, 0xDEADBEF0
    bne x2, t0, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
