.include "macros.inc"
.global _start
.section .text
_start:
    li   a1, -8      # 0xFFFFFFF8
    srai a0, a1, 2   # Arithmetic shift. Expected: -2 (0xFFFFFFFE)
    li   t0, -2
    bne  a0, t0, fail_loop
    j pass_loop
pass_loop:
    write_tohost_success
    j pass_loop
fail_loop:
    write_tohost_failure
    j fail_loop
