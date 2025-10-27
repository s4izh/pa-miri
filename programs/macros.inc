.ifndef MACROS_INC
.equ MACROS_INC, 1

.macro write_tohost, value_reg
    sw \value_reg, -4(zero)
.endm

.endif
