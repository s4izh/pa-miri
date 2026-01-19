`ifndef _RV_ISA_PKG_
`define _RV_ISA_PKG_

package rv_isa_pkg;

    // opcodes
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_IMM    = 7'b0010011;
    localparam logic [6:0] OPCODE_OP     = 7'b0110011;
    localparam logic [6:0] OPCODE_FENCE  = 7'b0001111;
    localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;

    // funct3 for OP/IMM/BRANCH/LOAD/STORE
    localparam logic [2:0] F3_ADDI   = 3'b000;
    localparam logic [2:0] F3_ADDSUB = 3'b000;
    localparam logic [2:0] F3_MUL    = 3'b000;
    localparam logic [2:0] F3_SLLI   = 3'b001;
    localparam logic [2:0] F3_SLL    = 3'b001;
    localparam logic [2:0] F3_MULH   = 3'b001;
    localparam logic [2:0] F3_SLTI   = 3'b010;
    localparam logic [2:0] F3_SLT    = 3'b010;
    localparam logic [2:0] F3_MULHSU = 3'b010;
    localparam logic [2:0] F3_SLTIU  = 3'b011;
    localparam logic [2:0] F3_SLTU   = 3'b011;
    localparam logic [2:0] F3_MULHU  = 3'b011;
    localparam logic [2:0] F3_XORI   = 3'b100;
    localparam logic [2:0] F3_XOR    = 3'b100;
    localparam logic [2:0] F3_DIV    = 3'b100;
    localparam logic [2:0] F3_SRI    = 3'b101;
    localparam logic [2:0] F3_SR     = 3'b101;
    localparam logic [2:0] F3_DIVU   = 3'b101;
    localparam logic [2:0] F3_ORI    = 3'b110;
    localparam logic [2:0] F3_OR     = 3'b110;
    localparam logic [2:0] F3_REM    = 3'b110;
    localparam logic [2:0] F3_ANDI   = 3'b111;
    localparam logic [2:0] F3_AND    = 3'b111;
    localparam logic [2:0] F3_REMU   = 3'b111;

    // funct3 for BEQ/BNE/BLT/BGE/BLTU
    localparam logic [2:0] F3_BEQ    = 3'b000;
    localparam logic [2:0] F3_BNE    = 3'b001;
    localparam logic [2:0] F3_BLT    = 3'b100;
    localparam logic [2:0] F3_BGE    = 3'b101;
    localparam logic [2:0] F3_BLTU   = 3'b110;
    localparam logic [2:0] F3_BGEU   = 3'b111;

    // funct3 for LB/LH/LW/LBU/LHU
    localparam logic [2:0] F3_LB     = 3'b000;
    localparam logic [2:0] F3_LH     = 3'b001;
    localparam logic [2:0] F3_LW     = 3'b010;
    localparam logic [2:0] F3_LBU    = 3'b100;
    localparam logic [2:0] F3_LHU    = 3'b101;

    // funct3 for SB/SH/SW
    localparam logic [2:0] F3_SB     = 3'b000;
    localparam logic [2:0] F3_SH     = 3'b001;
    localparam logic [2:0] F3_SW     = 3'b010;

    // funct7 for OP/IMM
    localparam logic [6:0] F7_ADD    = 7'b0000000;
    localparam logic [6:0] F7_SUB    = 7'b0100000;
    localparam logic [6:0] F7_SRA    = 7'b0100000;
    localparam logic [6:0] F7_SRL    = 7'b0000000;
    localparam logic [6:0] F7_MULDIV = 7'b0000001;

    // funct3 for CSR[RW|RC|RS][I]
    localparam logic [2:0] F3_CSRRW  = 3'b001;
    localparam logic [2:0] F3_CSRRS  = 3'b010;
    localparam logic [2:0] F3_CSRRC  = 3'b011;
    localparam logic [2:0] F3_CSRRWI = 3'b101;
    localparam logic [2:0] F3_CSRRSI = 3'b110;
    localparam logic [2:0] F3_CSRRCI = 3'b111;

    // EXCEPTIONS and INTERRUPTS: interrupt bit is the MSB of mcause
    localparam logic [31:0] MCAUSE_INTERRUPT_BIT     = 32'h8000_0000;

    // EXCEPTIONS
    localparam logic [31:0] EXC_CAUSE_INSTR_ADDR_MISALIGNED     = 32'd0;
    localparam logic [31:0] EXC_CAUSE_INSTR_ACCESS_FAULT        = 32'd1;
    localparam logic [31:0] EXC_CAUSE_ILLEGAL_INSTR             = 32'd2;
    localparam logic [31:0] EXC_CAUSE_BREAKPOINT                = 32'd3;
    localparam logic [31:0] EXC_CAUSE_LOAD_ADDR_MISALIGNED      = 32'd4;
    localparam logic [31:0] EXC_CAUSE_LOAD_ACCESS_FAULT         = 32'd5;
    localparam logic [31:0] EXC_CAUSE_STORE_AMO_ADDR_MISALIGNED = 32'd6;
    localparam logic [31:0] EXC_CAUSE_STORE_AMO_ACCESS_FAULT    = 32'd7;
    localparam logic [31:0] EXC_CAUSE_ECALL_U_MODE              = 32'd8;
    localparam logic [31:0] EXC_CAUSE_ECALL_S_MODE              = 32'd9;
    // localparam logic [31:0] EXC_CAUSE_ECALL_M_MODE              = 32'd11;
    localparam logic [31:0] EXC_CAUSE_INSTR_PAGE_FAULT          = 32'd12;
    localparam logic [31:0] EXC_CAUSE_LOAD_PAGE_FAULT           = 32'd13;
    localparam logic [31:0] EXC_CAUSE_STORE_AMO_PAGE_FAULT      = 32'd15;

    // INTERRUPTS
    localparam logic [31:0] INT_CAUSE_S_SOFTWARE_INT       = MCAUSE_INTERRUPT_BIT + 32'd1;
    localparam logic [31:0] INT_CAUSE_S_TIMER_INT          = MCAUSE_INTERRUPT_BIT + 32'd5;
    localparam logic [31:0] INT_CAUSE_S_EXTERNAL_INT       = MCAUSE_INTERRUPT_BIT + 32'd9;
    localparam logic [31:0] INT_CAUSE_COUNTER_OVERFLOW_INT = MCAUSE_INTERRUPT_BIT + 32'd13;

    typedef enum logic {
        TRAP_TYPE_EXCEPTION = 0,
        TRAP_TYPE_INTERRUPT = 1
    } trap_type_e;

    typedef struct packed {
        logic valid;
        trap_type_e trap_type;
        logic [31:0] cause;
    } trap_t;

endpackage

`endif
