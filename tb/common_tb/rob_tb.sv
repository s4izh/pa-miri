// This module is instantiated by the top_tb_wrapper
module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam XLEN = 32;
    localparam MEM_ALEN = 12;
    localparam MEM_DLEN = 32;

    // DUT signals

    // Instantiate the DUT
    rob #(
        .XLEN(XLEN)
    ) dut (.*);

    // Test sequence
    initial begin
        noop(valid_i, we_i, addr_i, data_i, width_i);
        @(posedge reset_n);
        @(posedge clk);

        // test_directed();
        test_random(100, 50, 32'h0000_1000);

        noop(valid_i, we_i, addr_i, data_i, width_i);
        @(posedge clk);
        $finish;
    end

    // - An issuing instructions generator
    // - A completing instructions generator
    // - A commiting instructions monitor

    task test_random(input int n_ops, input int write_prob, input logic[XLEN-1:0] addr_base);
        logic [3:0] addr_offset;
        logic [XLEN-1:0] data;
        memop_width_e width;
        for (int i = 0; i < n_ops; ++i) begin
            // Randomize
            addr_offset = $urandom_range(0, 1<<4);
            data = $urandom_range(0, 1<<32);
            width = memop_width_e'($urandom_range(0, 1<<2));
            if ($urandom_range(1,100) < write_prob) begin
                write(addr_base+addr_offset, width, data,
                    valid_i, we_i, addr_i, data_i, width_i);
            end else begin
                read(addr_base+addr_offset, width,
                    valid_i, we_i, addr_i, data_i, width_i);
            end
            @(posedge clk);
        end
    endtask

    task test_directed();
        @(posedge clk);
        write(32'h00000105, MEMOP_WIDTH_8, 32'h000000ca,
            valid_i, we_i, addr_i, data_i, width_i);
        @(posedge clk);
        write(32'h00000100, MEMOP_WIDTH_32, 32'hcac0cafe,
            valid_i, we_i, addr_i, data_i, width_i);
        @(posedge clk);
        read(32'h00000100, MEMOP_WIDTH_16,
            valid_i, we_i, addr_i, data_i, width_i);
        @(posedge clk);
        read(32'h00000102, MEMOP_WIDTH_16,
            valid_i, we_i, addr_i, data_i, width_i);
        @(posedge clk);
        read(32'h00000104, MEMOP_WIDTH_16,
            valid_i, we_i, addr_i, data_i, width_i);
        @(posedge clk);
    endtask

    task issue (
        input logic[XLEN-1:0] pc,
        input logic[4:0] rd,

        // output robid_t robid;
    );
    endtask

    task complete (
        input robid;
    );
    endtask

    task noop (
        output logic valid_i,
        output logic we_i,
        output logic[XLEN-1:0] addr_i,
        output logic[XLEN-1:0] data_i,
        output memop_width_e width_i
    );
        valid_i = 0;
        we_i    = 0;
        addr_i  = '0;
        data_i  = '0;
        width_i = MEMOP_WIDTH_INVALID;
    endtask

endmodule
