`timescale 1ns/1ps

module tb (
    input logic clk,
    input logic reset_n
);
    localparam XLEN = 32;
    localparam NREG = 32;
    localparam INS_WIDTH = 32;

    logic[INS_WIDTH-1:0] ins_i;
    logic [XLEN-1:0] immed;
    logic [4:0] ra_o;
    logic [4:0] rb_o;
    logic [4:0] rd_o;
    logic mux_ra_o;
    logic mux_rb_o;
    logic mux_mem_o;
    logic is_wb_o;
    logic is_st_o;
    logic mux_pc_o;

    initial begin
        @(posedge reset_n);
        repeat(100) @(posedge clk);
        $display("Finished");
        $finish;
    end

    decoder #(
        .XLEN(XLEN),
        .INS_WIDTH(INS_WIDTH),
        .NREG(NREG)
    ) dut (.*);

    always @(posedge clk) begin
        if (!reset_n) begin
            ins_i <= 32'h1234567;
            $display("Reset applied");
        end else begin
            ins_i <= ins_i + INS_WIDTH'(1);
        end
    end

endmodule
