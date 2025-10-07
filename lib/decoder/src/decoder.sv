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
    output logic mux_ra_o,
    output logic mux_rb_o,
    output logic mux_mem_o,
    output logic is_wb_o,
    output logic is_st_o,
    output logic mux_pc_o
);
    import decoder_pkg::*;

    localparam int NREG_WIDTH = $clog2(NREG);

    decoder_pkg::opcode_e opcode;

    assign opcode = opcode_e'(ins_i[decoder_pkg::OPCODE_WIDTH-1:0]);

    // Sign extended immediate extracted from the instruction
    // assign immed_o = $signed(ins_i[XLEN-1:19]); // Sign extended
    always_comb begin
        case (opcode)
            OPCODE_LI:
                immed_o = $signed(ins_i[XLEN-1:1*NREG_WIDTH+OPCODE_WIDTH]);
            default:
                immed_o = $signed(ins_i[XLEN-1:3*NREG_WIDTH+OPCODE_WIDTH]);
        endcase
    end

    // Addresses of all regiters of the operation
    assign rd_o = ins_i[1*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];
    assign rb_o = ins_i[2*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];
    assign ra_o = ins_i[3*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];

    // Decides the entry of ra into the adder
    assign mux_ra_o = 0;
    // Decides the entry of rb into the adder
    assign mux_rb_o = 0;

    // Indicates who is writen back: memory or arithmetic result (also called
    // is_load by Roger)
    assign mux_mem_o = (opcode == OPCODE_LW) ? 1'b1 : 1'b0;

    // Indicates if there is a result to write back into the register file
    // assign is_wb_o = (opcode inside {OPCODE_ADD, OPCODE_LI, OPCODE_LW}) ? 1'b1 : 1'b0;
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

    // Decides what address is written into the pc register
    assign mux_pc_o = 0;

endmodule
