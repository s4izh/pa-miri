typedef enum logic [0:0] {
    MUX_ALU_A_RS1,
    MUX_ALU_A_PC
} mux_alu_a_sel_e;

typedef enum logic [0:0] {
    MUX_ALU_B_RS2,
    MUX_ALU_B_IMM
} mux_alu_b_sel_e;

typedef enum logic [0:0] {
    MUX_WB_ALU,
    MUX_WB_MEM,
    MUX_WB_PC4 // for JAL/JALR
} mux_wb_sel_e;

typedef enum logic [0:0] {
    PC_PLUS_4,
    PC_JUMP // for JAL/JALR and taken Branches
    // exceptions ??
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

// funct7 for OP/IMM
localparam logic [6:0] F7_ADD    = 7'b0000000;
localparam logic [6:0] F7_SUB    = 7'b0100000;
localparam logic [6:0] F7_SRA    = 7'b0100000;
localparam logic [6:0] F7_SRL    = 7'b0000000;
