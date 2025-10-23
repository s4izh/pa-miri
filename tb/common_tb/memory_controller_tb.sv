import memory_controller_pkg::*;

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
    memop_width_e width_i;

    // Core output
    logic valid_o, xcpt_o;
    logic [XLEN-1:0] data_o;

    // Mem output
    logic [MEM_ALEN-1:0] mem_addr_o;
    logic [(MEM_DLEN/8)-1:0] mem_byte_en_o;
    logic [MEM_DLEN-1:0] mem_data_o;
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
        .byte_en_i(mem_byte_en_o),
        .data_i(mem_data_o),
        .data_o(mem_data_i)
    );

    // Test sequence
    initial begin
        valid_i = 0;
        we_i = 0;
        addr_i = 0;
        data_i = 0;
        width_i = MEMOP_WIDTH_INVALID;

        @(posedge reset_n);
        @(posedge clk);

        // Write
        valid_i = 1;
        we_i = 1;
        // addr_i = 32'h00001234;
        addr_i = 32'h00000003;
        data_i = 32'h000000ca;
        width_i = MEMOP_WIDTH_8;

        @(posedge clk);

        // Read
        valid_i = 1;
        we_i = 0;
        addr_i = 32'h00000000;
        width_i = MEMOP_WIDTH_32;

        @(posedge clk);

        $finish;
    end

endmodule
