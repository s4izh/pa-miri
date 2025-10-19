module top_tb_wrapper;

    logic clk;
    logic reset_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_inst);

        reset_n = 1'b0;
        repeat(5) @(posedge clk);
        reset_n = 1'b1;
    end

    tb tb_inst (
        .clk(clk),
        .reset_n(reset_n)
    );

endmodule
