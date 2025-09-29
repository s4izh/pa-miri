`timescale 1ns/1ps

module regfile#(
    parameter int XLEN = 32,
    parameter int NREG = 32,
    parameter int ADDR_WIDTH = $clog2(NREG)
)(
    input logic clk,
    input logic reset_n,

    // Read port a
    input logic [ADDR_WIDTH-1:0] ra_addr_i,
    output logic [XLEN-1:0] ra_data_o,

    // Read port b
    input logic [ADDR_WIDTH-1:0] rb_addr_i,
    output logic [XLEN-1:0] rb_data_o,

    // Write port d
    input logic [ADDR_WIDTH-1:0] rd_addr_i,
    input logic [XLEN-1:0] rd_data_i,
    input logic rd_we_i
);

    logic [NREG-1:0][XLEN-1:0] regs;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            for (int i = 0; i < NREG; ++i) begin
                regs[i] <= 0;
            end
        end else if (rd_we_i) begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end

    assign ra_data_o = regs[ra_addr_i];
    assign rb_data_o = regs[rb_addr_i];

endmodule
