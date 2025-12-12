// This module is instantiated by the top_tb_wrapper
module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam int XLEN = 32;
    localparam int WAYS = 4;
    localparam int _LINES = 4;
    localparam int _CACHELINE_BYTES = 16;
    localparam int ROM_ADDR_WIDTH = 5;

    // DUT signals
    // Interface with core (d for data)
    logic            dreq_valid_i;
    logic            dreq_ready_o;
    logic [XLEN-1:0] dreq_addr_i;
    logic [XLEN-1:0] drsp_data_o;
    logic            drsp_xcpt_o;
    // Interface with memory (f for fill)
    logic                            freq_valid_o;
    logic [XLEN-1:0]                 freq_addr_o;
    logic                            frsp_valid_i;
    logic [(_CACHELINE_BYTES*8)-1:0] frsp_data_i;

    // Instantiate the DUT
    icache #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        ._LINES(_LINES),
        ._CACHELINE_BYTES(_CACHELINE_BYTES)
    ) dut (.*);

    // Other instances
    rom #(
        .DATA_WIDTH(_CACHELINE_BYTES*8),
        .ADDR_WIDTH(ROM_ADDR_WIDTH)
    ) rom_inst (
        .addr_i(freq_addr_o[ROM_ADDR_WIDTH+$clog2(_CACHELINE_BYTES)-1:$clog2(_CACHELINE_BYTES)]),
        .data_o(frsp_data_i)
    );
    initial begin
        for (int i = 0; i < 2**ROM_ADDR_WIDTH; ++i) begin
            rom_inst.mem[i] = {$urandom(), $urandom(), $urandom(), $urandom()};
        end
    end


    logic [3:0] valid_queue;
    logic prev_valid;
    always @(posedge clk) begin
        valid_queue[3] <= valid_queue[2];
        valid_queue[2] <= valid_queue[1];
        valid_queue[1] <= valid_queue[0];
        if (!prev_valid)
            valid_queue[0] <= freq_valid_o;
        else
            valid_queue[0] <= 0;
        prev_valid <= freq_valid_o;
    end
    assign frsp_valid_i = valid_queue[3];

    initial begin
        int to = 1000;
        while (to > 0) begin
            to = to - 1;
            @(posedge clk);
        end
        $fatal("TIMEOUT");
    end

    // Test sequence
    initial begin
        noop(dreq_valid_i);
        @(posedge reset_n);
        @(posedge clk);

        test_directed();

        noop(dreq_valid_i);
        @(posedge clk);
        $finish;
    end

    task test_directed();
        for (int k = 0; k < 2; ++k) begin
            for (logic[XLEN-1:0] i = 0; i < 20; ++i) begin
                while (!dreq_ready_o) @(posedge clk)
                dreq_valid_i = 1;
                dreq_addr_i  = 0'h1AA+4*i;
                @(posedge clk);
                while (!dreq_ready_o) @(posedge clk)
                $display("%0t icache response! %x", $time, drsp_data_o);
            end
        end
    endtask

    task noop (
        output logic dreq_valid_i
    );
        dreq_valid_i = 0;
    endtask

endmodule
