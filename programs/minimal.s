.global _start      # make the _start symbol visible to the linker

.section .text      # code section
_start:
    li  a0, 5       # Load immediate value 5 into register a0 (x10)
    li  a1, 10      # Load immediate value 10 into register a1 (x11)
    add a2, a0, a1  # Add a0 and a1, store the result (15) in a2 (x12)

    li   a3, 1

    # Signal pass
    li t0, 0
    sw t0, -4(zero)

    # let's count forever
loop:
    addi a3, a3, 1
    j    loop
