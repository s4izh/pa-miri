package rv_datapath_pkg;
    typedef enum logic [0:0] {
        MUX_ALU_OP1_RS1,
        MUX_ALU_OP1_PC
    } mux_alu_op1_sel_e;

    typedef enum logic [1:0] {
        MUX_ALU_OP2_RS1,
        MUX_ALU_OP2_RS2,
        MUX_ALU_OP2_IMM
    } mux_alu_op2_sel_e;

    typedef enum logic [1:0] {
        MUX_WB_ALU,
        MUX_WB_MEM,
        MUX_WB_PC_NEXT // for JAL/JALR
    } mux_wb_sel_e;

    typedef enum logic [1:0] {
        MUX_PC_NEXT,      // PC = PC + 4 (default sequential execution)
        MUX_PC_BRANCH,    // PC = PC + immediate (conditional branch taken)
        MUX_PC_JAL,       // PC = PC + immediate (unconditional jump - JAL)
        MUX_PC_JALR       // PC = rs1 + immediate (unconditional jump - JALR)
    } mux_pc_sel_e;

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
    localparam logic [2:0] F3_SLLI   = 3'b001;
    localparam logic [2:0] F3_SLL    = 3'b001;
    localparam logic [2:0] F3_SLTI   = 3'b010;
    localparam logic [2:0] F3_SLT    = 3'b010;
    localparam logic [2:0] F3_SLTIU  = 3'b011;
    localparam logic [2:0] F3_SLTU   = 3'b011;
    localparam logic [2:0] F3_XORI   = 3'b100;
    localparam logic [2:0] F3_XOR    = 3'b100;
    localparam logic [2:0] F3_SRI    = 3'b101;
    localparam logic [2:0] F3_SR     = 3'b101;
    localparam logic [2:0] F3_ORI    = 3'b110;
    localparam logic [2:0] F3_OR     = 3'b110;
    localparam logic [2:0] F3_ANDI   = 3'b111;
    localparam logic [2:0] F3_AND    = 3'b111;

    // funct3 for BEQ/BNE/BLT/BGE/BLTU
    localparam logic [2:0] F3_BEQ    = 3'b000;
    localparam logic [2:0] F3_BNE    = 3'b001;
    localparam logic [2:0] F3_BLT    = 3'b100;
    localparam logic [2:0] F3_BGE    = 3'b110;
    localparam logic [2:0] F3_BLTU   = 3'b111;

    localparam logic [2:0] F3_LB     = 3'b000;
    localparam logic [2:0] F3_LH     = 3'b001;
    localparam logic [2:0] F3_LW     = 3'b010;
    localparam logic [2:0] F3_LBU    = 3'b100;
    localparam logic [2:0] F3_LHU    = 3'b101;

    // funct7 for OP/IMM
    localparam logic [6:0] F7_ADD    = 7'b0000000;
    localparam logic [6:0] F7_SUB    = 7'b0100000;
    localparam logic [6:0] F7_SRA    = 7'b0100000;
    localparam logic [6:0] F7_SRL    = 7'b0000000;


    typedef enum logic [2:0] {
        COMPARE_OP_BEQ,
        COMPARE_OP_BNE,
        COMPARE_OP_BLT,
        COMPARE_OP_BGE,
        COMPARE_OP_BLTU,
        COMPARE_OP_NONE
    } compare_op_e;
endpackage
