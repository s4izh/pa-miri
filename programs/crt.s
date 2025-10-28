.include "macros.inc"

.global _start
.section .text
_start:
    # tohost is 3ffc, so 3ff8 is the last usable word-aligned address. use that as stack-top
    li sp, 0x3ff8
    jal ra, main
write_tohost:
    sw a0, -4(zero)
    j write_tohost

.global _trap_handler
.section .text._trap_handler
_trap_handler:
    li a0, 1
    j write_tohost

