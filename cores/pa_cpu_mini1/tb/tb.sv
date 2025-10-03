`timescale 1ns/1ps

module tb (
    input logic clk,
    input logic reset_n
);

    string test_filename = "";

    parameter int XLEN = 32;
    parameter int ALEN = 5;
    parameter int NREG = 32;
    parameter int ADDR_WIDTH = $clog2(NREG);
    parameter int DMEM_SIZE = 4096;
    parameter int IMEM_SIZE = 4096;
    parameter int DMEM_ADDR_WIDTH = $clog2(DMEM_SIZE);
    parameter int IMEM_ADDR_WIDTH = $clog2(IMEM_SIZE);

    logic[IMEM_ADDR_WIDTH-1:0]   imem_addr_o;
    logic[XLEN-1:0]              imem_data_i;

    logic[IMEM_ADDR_WIDTH-1:0]   dmem_addr_o;
    logic[XLEN-1:0]              dmem_data_o;
    logic                        dmem_we_o;
    logic[XLEN-1:0]              dmem_data_i;

    pa_cpu_mini1 #(
        .XLEN(XLEN)
    ) dut (.*);

    rom #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) imem (
        .addr_i(imem_addr_o),
        .data_o(imem_data_i)
    );

    sram #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) dmem (
        .clk,
        .addr_i(dmem_addr_o),
        .we_i(dmem_we_o),
        .data_i(dmem_data_o),
        .data_o(dmem_data_i)
    );

    initial begin
        if ($value$plusargs("TEST_FILE=%s", test_filename)) begin
            $display("Test filename: %s", test_filename);
        end else begin
            $display("No test provided. Running with empty imem");
        end
    end

    initial begin
        @(posedge reset_n)
        repeat(100) @(posedge clk);
        $finish;
    end

    // Monitor signals
    initial begin
        // $monitor("Time: %0t | Reset: %b | State: %d | Data_in: 0x%02h | Data_out: 0x%02h | Valid: %b",
        //          $time, reset_n, dut.current_state, data_in, data_out, valid_out);
        $monitor("Time: %0t | Clock: %b | Reset: %b",
                 $time, clk, reset_n);
    end

endmodule
