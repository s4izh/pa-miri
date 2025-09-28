`timescale 1ns/1ps

module regfile#(
    parameter int XLEN = 32,
    parameter int NREG = 32,
    parameter int ADDR_WIDTH = $clog2(NREG)
    )(
    input logic clk,
    input logic reset_n,
    input logic [ADDR_WIDTH-1:0] ra_addr,
    input logic [ADDR_WIDTH-1:0] rb_addr,
    input logic rd_we,
    input logic [ADDR_WIDTH-1:0] rd_addr,
    input logic [XLEN-1:0] rd_data,
    output logic [XLEN-1:0] ra_data,
    output logic [XLEN-1:0] rb_data
);
    logic [NREG-1:0][XLEN-1:0] regs;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            for (int i = 0; i < NREG; ++i) begin
                regs[i] <= 0;
            end
        end else if (rd_we) begin
            regs[rd_addr] <= rd_data;
        end
    end

    assign ra_data = regs[ra_addr];
    assign rb_data = regs[rb_addr];

endmodule
