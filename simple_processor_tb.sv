// Testbench for Simple Processor
// This testbench verifies the basic functionality of the simple processor

`timescale 1ns/1ps

module simple_processor_tb;

    // Clock and reset signals
    logic clk;
    logic reset_n;
    
    // Data signals
    logic [7:0] data_in;
    logic [7:0] data_out;
    logic       valid_out;
    
    // Instantiate DUT (Device Under Test)
    simple_processor dut (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(data_in),
        .data_out(data_out),
        .valid_out(valid_out)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock (10ns period)
    end
    
    // Test sequence
    initial begin
        // Generate VCD waveform file
        $dumpfile("simple_processor.vcd");
        $dumpvars(0, simple_processor_tb);
        
        // Initialize signals
        reset_n = 0;
        data_in = 8'h00;
        
        // Apply reset
        #20;
        reset_n = 1;
        
        // Test case 1: Input value 0x10
        data_in = 8'h10;
        
        // Wait for one complete cycle (4 clock cycles)
        #40;
        
        // Check output when valid
        @(posedge valid_out);
        if (data_out == 8'h11) begin
            $display("TEST PASS: Input 0x%02h -> Output 0x%02h (Expected 0x11)", 8'h10, data_out);
        end else begin
            $display("TEST FAIL: Input 0x%02h -> Output 0x%02h (Expected 0x11)", 8'h10, data_out);
        end
        
        // Test case 2: Input value 0x20
        data_in = 8'h20;
        
        // Wait for another complete cycle
        #40;
        
        // Check output when valid
        @(posedge valid_out);
        if (data_out == 8'h21) begin
            $display("TEST PASS: Input 0x%02h -> Output 0x%02h (Expected 0x21)", 8'h20, data_out);
        end else begin
            $display("TEST FAIL: Input 0x%02h -> Output 0x%02h (Expected 0x21)", 8'h20, data_out);
        end
        
        // Test case 3: Input value 0xFF (test overflow)
        data_in = 8'hFF;
        
        // Wait for another complete cycle
        #40;
        
        // Check output when valid
        @(posedge valid_out);
        if (data_out == 8'h00) begin
            $display("TEST PASS: Input 0x%02h -> Output 0x%02h (Expected 0x00 - overflow)", 8'hFF, data_out);
        end else begin
            $display("TEST FAIL: Input 0x%02h -> Output 0x%02h (Expected 0x00 - overflow)", 8'hFF, data_out);
        end
        
        $display("\nSimulation completed successfully!");
        $finish;
    end
    
    // Monitor signals
    initial begin
        $monitor("Time: %0t | Reset: %b | State: %d | Data_in: 0x%02h | Data_out: 0x%02h | Valid: %b", 
                 $time, reset_n, dut.current_state, data_in, data_out, valid_out);
    end

endmodule