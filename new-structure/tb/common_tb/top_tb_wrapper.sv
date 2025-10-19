module top_tb_wrapper;
    logic clk;
    logic reset_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        reg [128*8-1:0] vcd_filename;

        if ($value$plusargs("VCD_FILE=%s", vcd_filename)) begin
            $display("VCD dumping enabled. Output file: %s", vcd_filename);
            $dumpfile(vcd_filename);
            $dumpvars(0, child_tb_inst);
        end else begin
            $display("VCD dumping disabled. To enable, pass +VCD_FILE=<filename> to the simulator.");
        end

        reset_n = 0;

        repeat(3) @(negedge clk);

        reset_n = 1;
    end

    tb child_tb_inst (.*);

endmodule
