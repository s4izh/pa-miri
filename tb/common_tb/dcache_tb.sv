// This module is instantiated by the top_tb_wrapper
module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam int XLEN = 32;
    localparam int WAYS = 4;
    localparam int SETS = 4;
    localparam int BITS_CACHELINE = 128;
    localparam int SRAM_ADDR_WIDTH = 5;

    // DUT signals
    // Interface with core (d for data)
    // Request
    logic                                dreq_valid_i;
    logic                                dreq_ready_o;
    logic [XLEN-1:0]                     dreq_addr_i;
    logic [XLEN-1:0]                     dreq_data_i;
    logic                                dreq_we_i;
    memory_controller_pkg::memop_width_e dreq_width_i;
    // Response
    logic                                drsp_hit_o;
    logic [XLEN-1:0]                     drsp_data_o;
    logic                                drsp_xcpt_o;
    // Interface with memory (f for fill)
    // Request
    logic                                freq_valid_o;
    logic                                freq_we_o;
    logic [BITS_CACHELINE-1:0]           freq_data_o;
    logic [XLEN-1:0]                     freq_addr_o;
    // Response
    logic                                frsp_valid_i;
    logic [BITS_CACHELINE-1:0]           frsp_data_i;

    logic [XLEN-1:0]                     addr;

    // Instantiate the DUT
    dcache_wrapper #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) dut (.*);

    assign addr = (freq_addr_o >> $clog2(BITS_CACHELINE/8));

    // Other instances
    sram #(
        .DATA_WIDTH(BITS_CACHELINE),
        .ADDR_WIDTH(SRAM_ADDR_WIDTH)
    ) sram_inst (
        .clk,
        .addr_i( { addr[SRAM_ADDR_WIDTH-1:0] } ),
        .we_i(freq_we_o),
        .byte_en_i('1),
        .data_i(freq_data_o),
        .data_o(frsp_data_i)
    );
    initial begin
        for (int i = 0; i < 2**SRAM_ADDR_WIDTH; ++i) begin
            sram_inst.mem[i] = {
                  $urandom(), $urandom(), $urandom(), $urandom() // 128b
                // , $urandom(), $urandom(), $urandom(), $urandom() // 128b
            };
        end
    end


    localparam MEM_DELAY = 5;
    logic [MEM_DELAY-1:0] valid_queue;
    always @(posedge clk) begin
        // Propagate
        for (int i = 1; i < MEM_DELAY; ++i) begin
            valid_queue[i] <= valid_queue[i-1];
        end
        // Insert at the bottom
        if (!(|valid_queue))
            valid_queue[0] <= freq_valid_o;
        else
            valid_queue[0] <= 0;
    end
    assign frsp_valid_i = valid_queue[MEM_DELAY-1];

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
        noop();
        @(posedge reset_n);
        @(posedge clk);

        test_directed();

        noop();
        @(posedge clk);
        $finish;
    end

    task test_directed();
        for (int k = 0; k < 2; ++k) begin
            for (logic[XLEN-1:0] i = 0; i < 20; ++i) begin
                while (!dreq_ready_o) begin
                    @(posedge clk);
                end

                if ($urandom_range(1,100) < 50) begin
                    read(0'h100+4*i, MEMOP_WIDTH_32);
                end else begin
                    write((0'h100+4*i), MEMOP_WIDTH_32, 32'hcafecafe);
                end

                @(posedge clk);
                while (!dreq_ready_o) begin
                    @(posedge clk);
                end
                // noop();
                $display("%0t icache response! %x", $time, drsp_data_o);
            end
        end
    endtask

    task noop ();
        dreq_valid_i = 0;
        dreq_we_i    = 0;
    endtask

    task read (
        input logic[XLEN-1:0] addr,
        input memop_width_e   width,
    );
        dreq_valid_i = 1;
        dreq_we_i    = 0;
        dreq_addr_i  = addr;
        dreq_width_i = width;
        dreq_data_i  = '0;
    endtask

    task write (
        input logic[XLEN-1:0] addr,
        input memop_width_e   width,
        input logic[XLEN-1:0] data,
    );
        dreq_valid_i = 1;
        dreq_we_i    = 1;
        dreq_addr_i  = addr;
        dreq_width_i = width;
        dreq_data_i  = data;
    endtask

endmodule
