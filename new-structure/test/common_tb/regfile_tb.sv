// This module is instantiated by the top_tb_wrapper
module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam XLEN = 32;
    localparam NREG = 32;

    // DUT signals
    logic [4:0]      rs1_addr_i, rs2_addr_i, rd_addr_i;
    logic [XLEN-1:0] rs1_data_o, rs2_data_o, rd_data_i;
    logic            rd_we_i;

    // Instantiate the DUT (Design Under Test)
    regfile #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) dut (.*);

    // Test sequence
    initial begin
        // Initialize signals to prevent unknowns
        rs1_addr_i <= 0;
        rs2_addr_i <= 0;
        rd_addr_i  <= 0;
        rd_data_i  <= 0;
        rd_we_i    <= 0;

        // Wait for reset to finish
        @(posedge reset_n);
        $display("[%0t] Reset released. Starting test.", $time);

        // --- Test 1: Write to x5, then read it back on the NEXT cycle ---
        $display("[%0t] Test 1: Writing 0xDEADBEEF to x5", $time);
        rd_we_i   <= 1'b1;
        rd_addr_i <= 5;
        rd_data_i <= 32'hDEADBEEF;

        @(posedge clk); // Cycle 1: Write occurs at this edge.

        // --- THE FIX IS HERE ---
        // At the start of Cycle 2, stop the write and set the read addresses.
        rd_we_i <= 1'b0;
        rs1_addr_i <= 5;
        rs2_addr_i <= 5;

        // The asynchronous read is now reading the *stable*, updated value from the FF.
        // We will check it on the next clock edge to be sure.
        @(posedge clk); // Cycle 2: Wait for the full cycle to pass.

        // At the start of Cycle 3, the data read from Cycle 2 is stable.
        assert (rs1_data_o == 32'hDEADBEEF) else $fatal(1, "Port A read mismatch! Got %h", rs1_data_o);
        assert (rs2_data_o == 32'hDEADBEEF) else $fatal(1, "Port B read mismatch! Got %h", rs2_data_o);
        $display("[%0t] Port rs1 read: %h", $time, rs1_data_o);
        $display("[%0t] Port rs2 read: %h", $time, rs2_data_o);


        // --- Test 2: Ensure x0 is always zero ---
        $display("[%0t] Test 2: Attempting to write to x0 (should be ignored)", $time);
        rd_we_i   <= 1'b1;
        rd_addr_i <= 0;
        rd_data_i <= 32'hA5A5A5A5;

        @(posedge clk); // Write attempt is ignored by the hardware at this edge.
        
        rd_we_i <= 1'b0;
        rs1_addr_i <= 0; // Set read address for x0

        @(posedge clk); // Wait for one cycle.

        // Check the result.
        assert (rs1_data_o == 32'h0) else $fatal(1, "x0 is not hardwired to zero!");
        $display("[%0t] Read from x0: %h (Correct)", $time, rs1_data_o);


        $display("[%0t] All Register File tests PASSED!", $time);
        $finish;
    end

endmodule
