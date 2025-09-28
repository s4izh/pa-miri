// Testbench for Simple Processor
// This testbench verifies the basic functionality of the simple processor

`timescale 1ns/1ps

module pa_cpu_mini1_tb;

    logic clk;
    logic reset_n;
    
    pa_cpu_mini1 dut (
        .clk(clk),
        .reset_n(reset_n)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        $dumpfile("pa_cpu_mini1.vcd");
        $dumpvars(0, simple_processor_tb);
        
        reset_n = 0;

        repeat(3) @(posedge clk);
        
        reset_n = 1;

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
