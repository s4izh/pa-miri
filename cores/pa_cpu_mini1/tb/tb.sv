`timescale 1ns/1ps

module tb (
    input logic clk,
    input logic reset_n
);

    pa_cpu_mini1 dut (
        .clk(clk),
        .reset_n(reset_n)
    );

    initial begin
        @(posedge clk)
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
