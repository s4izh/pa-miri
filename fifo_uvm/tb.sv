module tbench_top;
    import uvm_pkg::*;
    import fifo_pkg::*;

    bit clk;

    always #5 clk = ~clk;

    fifo_if intf (.clk(clk));

    fifo #(
        .DEPTH(8),
        .WIDTH(8)
    ) dut (
        .clk      (clk),
        .rst_n    (intf.rst_n),
        .wr_en    (intf.wr_en),
        .wr_data  (intf.wr_data),
        .rd_en    (intf.rd_en),
        .rd_data  (intf.rd_data),
        .rd_valid (intf.rd_valid),
        .full     (intf.full),
        .empty    (intf.empty)
    );

    initial begin
        intf.rst_n = 0;
        #12 intf.rst_n = 1;
    end

    initial begin
        uvm_config_db #(virtual fifo_if)::set(uvm_root::get(), "*", "vif", intf);
    end

    initial begin
        run_test();
    end

endmodule
