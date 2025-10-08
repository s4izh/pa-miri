import datapath_pkg::*;

module decoder #(
    parameter int XLEN = 32,
    parameter int INS_WIDTH = 32,
    parameter int NREG = 32
)(
    input logic[INS_WIDTH-1:0] ins_i,
    output logic [XLEN-1:0] immed_o,
    output logic [4:0] ra_o,
    output logic [4:0] rb_o,
    output logic [4:0] rd_o,
    output mux_ra_e mux_ra_o,
    output mux_rb_e mux_rb_o,
    output logic is_ld_o,
    output logic is_wb_o,
    output logic is_st_o
);
    // Local parameters
    localparam int OPCODE_WIDTH = 4;
    localparam int NREG_WIDTH = $clog2(NREG);

    // Opcode enumeration
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

    opcode_e opcode;

    assign opcode = opcode_e'(ins_i[OPCODE_WIDTH-1:0]);

    // Sign extended immediate extracted from the instruction
    always_comb begin
        case (opcode)
            OPCODE_LI:
                // 23 bit
                immed_o = $signed(ins_i[INS_WIDTH-1:1*NREG_WIDTH+OPCODE_WIDTH]);
            default:
                // 13 bit
                immed_o = $signed(ins_i[INS_WIDTH-1:3*NREG_WIDTH+OPCODE_WIDTH]);
        endcase
    end

    // Addresses of all regiters of the operation
    assign rd_o = ins_i[1*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];
    assign rb_o = ins_i[2*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];
    assign ra_o = ins_i[3*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];

    // Decides the entry of ra into the adder
    always_comb begin
        case (opcode)
            OPCODE_ADD,
            OPCODE_LW,
            OPCODE_SW:
                mux_ra_o = MUX_RA_RA;
            OPCODE_LI,
            OPCODE_JMP:
                mux_ra_o = MUX_RA_0;
            default:
                // Branches
                mux_ra_o = MUX_RA_PC;
        endcase
    end

    // Decides the entry of rb into the adder
    always_comb begin
        case (opcode)
            OPCODE_ADD,
            OPCODE_JMP:
                mux_rb_o = MUX_RB_RB;
            default:
                mux_rb_o = MUX_RB_IMMED;
        endcase
    end

    // Indicates who is writen back: memory or arithmetic result (also called
    // is_load by Roger)
    assign is_ld_o = (opcode == OPCODE_LW) ? 1'b1 : 1'b0;

    // Indicates if there is a result to write back into the register file
    always_comb begin
        case (opcode)
            OPCODE_ADD,
            OPCODE_LI,
            OPCODE_LW:
                is_wb_o = 1;
            default:
                is_wb_o = 0;
        endcase
    end

    // Active when the operation is a store
    assign is_st_o = (opcode == OPCODE_SW) ? 1'b1 : 1'b0;

endmodule
