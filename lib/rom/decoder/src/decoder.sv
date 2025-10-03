module decoder #(
    parameter int XLEN = 32,
    parameter int INS_WIDTH = 32,
    parameter int NREG = 32,
)(
    input logic[INS_WIDTH-1:0] ins_i,

    output logic [XLEN-1:0] immed,
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
    localparam int OPCODE_WIDTH = 4;
    localparam int NREG_WIDTH = $clog2(NREG);

    logic [OPCODE_WIDTH-1:0] opcode;

    assign opcode = ins_i[OPCODE_WIDTH-1:0];
    assign rd_o = ins_i[1*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];
    assign rb_o = ins_i[2*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];
    assign ra_o = ins_i[3*NREG_WIDTH+OPCODE_WIDTH-1 +: NREG_WIDTH];

    // TODO
    assign mux_ra_o = 0;
    assign mux_rb_o = 0;
    assign mux_mem_o = 0;
    assign is_wb_o = 0;
    assign is_st_o = 0;
    assign mux_pc_o = 0;

endmodule
