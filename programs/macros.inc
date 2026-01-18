.ifndef MACROS_INC
.equ MACROS_INC, 1

.macro check_all_registers
    add x1,  x1,  x0
    add x2,  x2,  x0
    add x3,  x3,  x0
    add x4,  x4,  x0
    add x5,  x5,  x0
    add x6,  x6,  x0
    add x7,  x7,  x0
    add x8,  x8,  x0
    add x9,  x9,  x0
    add x10, x10, x0
    add x11, x11, x0
    add x12, x12, x0
    add x13, x13, x0
    add x14, x14, x0
    add x15, x15, x0
    add x16, x16, x0
    add x17, x17, x0
    add x18, x18, x0
    add x19, x19, x0
    add x20, x20, x0
    add x21, x21, x0
    add x22, x22, x0
    add x23, x23, x0
    add x24, x24, x0
    add x25, x25, x0
    add x26, x26, x0
    add x27, x27, x0
    add x28, x28, x0
    add x29, x29, x0
    add x30, x30, x0
    add x31, x31, x0
.endm

.macro shift_30_registers_right
    add x31, x30, x0
    add x30, x29, x0
    add x29, x28, x0
    add x28, x27, x0
    add x27, x26, x0
    add x26, x25, x0
    add x25, x24, x0
    add x24, x23, x0
    add x23, x22, x0
    add x22, x21, x0
    add x21, x20, x0
    add x20, x19, x0
    add x19, x18, x0
    add x18, x17, x0
    add x17, x16, x0
    add x16, x15, x0
    add x15, x14, x0
    add x14, x13, x0
    add x13, x12, x0
    add x12, x11, x0
    add x11, x10, x0
    add x10, x9,  x0
    add x9,  x8,  x0
    add x8,  x7,  x0
    add x7,  x6,  x0
    add x6,  x5,  x0
    add x5,  x4,  x0
    add x4,  x3,  x0
    add x3,  x2,  x0
    add x2,  x1,  x0
    add x1,  x31, x0
.endm

.macro shift_30_registers_left
    add x31, x1, x0
    add x1,  x2,  x0
    add x2,  x3,  x0
    add x3,  x4,  x0
    add x4,  x5,  x0
    add x5,  x6,  x0
    add x6,  x7,  x0
    add x7,  x8,  x0
    add x8,  x9,  x0
    add x9,  x10, x0
    add x10, x11, x0
    add x11, x12, x0
    add x12, x13, x0
    add x13, x14, x0
    add x14, x15, x0
    add x15, x16, x0
    add x16, x17, x0
    add x17, x18, x0
    add x18, x19, x0
    add x19, x20, x0
    add x20, x21, x0
    add x21, x22, x0
    add x22, x23, x0
    add x23, x24, x0
    add x24, x25, x0
    add x25, x26, x0
    add x26, x27, x0
    add x27, x28, x0
    add x28, x29, x0
    add x29, x30, x0
    add x30, x31, x0
.endm

.macro write_tohost_success
    check_all_registers
    # shift_30_registers_right
    # shift_30_registers_left
    li t0, 0
    sw t0, -4(zero)
    fence
.endm

.macro write_tohost_failure
    check_all_registers
    # shift_registers_right
    # shift_registers_left
    li t0, 1
    sw t0, -4(zero)
    fence
.endm

.macro check_test
    check_all_registers
    # shift_30_registers_right
    # shift_30_registers_left
.endm

.endif
