// This module is instantiated by the top_tb_wrapper
module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam XLEN = 32;
    localparam MEM_ALEN = 12;
    localparam MEM_DLEN = 32;

    // DUT signals
    // Core input
    logic valid_i, we_i;
    logic [XLEN-1:0] addr_i, data_i;
    logic [1:0] width_i; // 1, 2, 4, (unsupported)8

    // Core output
    logic valid_o, xcpt_o;
    logic [XLEN-1:0] data_o;

    // Mem output
    logic [MEM_DLEN-1:0] mem_addr_o;
    logic [MEM_ALEN-1:0] mem_data_o;
    logic mem_we_o;

    // Mem input
    logic [XLEN-1:0] mem_data_i;

    // Instantiate the DUT
    memory_controller #(
        .XLEN(XLEN),
        .MEM_ALEN(MEM_ALEN),
        .MEM_DLEN(MEM_DLEN)
    ) dut (.*);

    // Instantiate helper modules
    sram #(
        .DATA_WIDTH(MEM_DLEN),
        .ADDR_WIDTH(MEM_ALEN)
    ) sram_inst (
        .clk,
        .addr_i(mem_addr_o),
        .we_i(mem_we_o),
        .data_i(mem_data_o),
        .data_o(mem_data_i)
    );

    // Test sequence
    initial begin
        valid_i = 0;
        we_i = 0;
        addr_i = 0;
        data_i = 0;
        width_i = 0;

        @(posedge reset_n);
        @(posedge clk);

        valid_i = 1;
        we_i = 1;
        addr_i = 32'h00001234;
        data_i = 32'h000000ca;
        width_i = 0;

        @(posedge clk);

        valid_i = 1;
        we_i = 0;
        addr_i = 32'h00001234;
        width_i = 0;

        @(posedge clk);

        $finish;
    end

endmodule
