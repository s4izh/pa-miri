.include "macros.inc"
.global _start
.section .text
_start:
    # Test Set Less Than (Unsigned)
    li   a1, -1      # Unsigned: 0xFFFFFFFF (very large)
    li   a2, 100     # Unsigned: 100 (small)

    # Case 1: (100 < 0xFFFFFFFF) should be true (1)
    sltu a0, a2, a1
    li   t0, 1
    bne  a0, t0, fail_loop
    
    # Case 2: (0xFFFFFFFF < 100) should be false (0)
    sltu a0, a1, a2
    bne  a0, zero, fail_loop

    j pass_loop

pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
