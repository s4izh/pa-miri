`timescale 1ns/1ps

module pa_cpu_mini1_tb;

    logic clk;
    logic reset_n;

    pa_cpu_mini1 dut (
        .clk,
        .reset_n
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reg [128*8-1:0] vcd_filename;

        if ($value$plusargs("VCD_FILE=%s", vcd_filename)) begin
            $display("VCD dumping enabled. Output file: %s", vcd_filename);
            $dumpfile(vcd_filename);
            $dumpvars(0, pa_cpu_mini1_tb.dut);
        end else begin
            $display("VCD dumping disabled. To enable, pass +VCD_FILE=<filename> to the simulator.");
        end

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
