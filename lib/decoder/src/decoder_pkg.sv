package decoder_pkg;

    parameter int OPCODE_WIDTH = 4;

    typedef enum logic[OPCODE_WIDTH-1:0] {
        OPCODE_ADD = 4'b0001,
        OPCODE_LI  = 4'b0011,
        OPCODE_LW  = 4'b1000,
        OPCODE_SW  = 4'b1001,
        OPCODE_JMP = 4'b0100,
        OPCODE_BEQ = 4'b0101,
        OPCODE_BLT = 4'b0110,
        OPCODE_BGT = 4'b0111
    } opcode_e;

endpackage
