module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam XLEN = 32;
    localparam NREG = 32;

    localparam ADDR_WIDTH = $clog2(NREG);

    // Testbench signals
    logic [ADDR_WIDTH-1:0]  ra_addr_i, rb_addr_i, rd_addr_i;
    logic [XLEN-1:0]        ra_data_o, rb_data_o, rd_data_i;
    logic                   rd_we_i;

    // Instantiate DUT
    regfile #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) dut (.*);

    // Test procedure
    initial begin
        // Initialize signals
        ra_addr_i = 5'b0;
        rb_addr_i = 5'b0;
        rd_addr_i = 5'b0;
        rd_data_i = 32'h0;
        rd_we_i   = 1'b0;

        // Apply reset
        $display("Waiting for reset");
        @(posedge reset_n)

        // Write to register 1
        $display("-> Writing to register 1");
        rd_we_i = 1;
        rd_addr_i = 5'd1;
        rd_data_i = 32'hA5A5A5A5;
        repeat(1) @(posedge clk)

        // Read from register 1
        $display("-> Reading from register 1");
        ra_addr_i = 5'd1;
        repeat(1) @(posedge clk)
        $display("ra_data_o = %h", ra_data_o);

        // Write to register 2
        $display("-> Writing to register 2");
        rd_addr_i = 5'd2;
        rd_data_i = 32'hDEADBEEF;
        repeat(1) @(posedge clk)

        // Read from register 2
        $display("-> Reading from register 2");
        rb_addr_i = 5'd2;
        repeat(1) @(posedge clk)
        $display("rb_data_o = %h", rb_data_o);

        // Test complete
        $display("Test complete!");
        $finish;
    end

endmodule
