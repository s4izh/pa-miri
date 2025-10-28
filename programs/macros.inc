.ifndef MACROS_INC
.equ MACROS_INC, 1

;.macro write_tohost, value_reg
;    sw \value_reg, -4(zero)
;.endm

.macro write_tohost_success
    li t0, 0
    sw t0, -4(zero)
.endm

.macro write_tohost_failure
    li t0, 1
    sw t0, -4(zero)
.endm

.endif
