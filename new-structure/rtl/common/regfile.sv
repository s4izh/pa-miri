`ifndef _REGFILE_M_
`define _REGFILE_M_

module regfile #(
    parameter int XLEN = 32,
    parameter int NREG = 32,
    parameter int ADDR_WIDTH = $clog2(NREG)
)(
    input logic clk,
    input logic reset_n,

    // source 1
    input  logic [ADDR_WIDTH-1:0] rs1_addr_i,
    output logic [XLEN-1:0]       rs1_data_o,

    // source 2
    input  logic [ADDR_WIDTH-1:0] rs2_addr_i,
    output logic [XLEN-1:0]       rs2_data_o,

    // destination
    input  logic [ADDR_WIDTH-1:0] rd_addr_i,
    input  logic [XLEN-1:0]       rd_data_i,
    input  logic                  rd_we_i
);
    logic [NREG-1:0][XLEN-1:1] regs;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            for (int i = 0; i < NREG; ++i) begin
                regs[i] <= {XLEN{1'b0}};
            end
        end else if (rd_we_i && (rd_addr_i != 0)) begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end

    assign rs1_data_o = (rs1_addr_i == 0) ? {XLEN{1'b0}} : regs[rs1_addr_i];
    assign rs2_data_o = (rs2_addr_i == 0) ? {XLEN{1'b0}} : regs[rs2_addr_i];

endmodule

`endif
