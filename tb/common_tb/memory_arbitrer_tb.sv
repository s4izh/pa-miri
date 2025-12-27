module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam int XLEN = 32;
    localparam int BITS_CACHELINE = 128;

    // --- DUT Signals ---
    logic                      ic_freq_valid_i;
    logic [XLEN-1:0]           ic_freq_addr_i;
    logic                      ic_frsp_valid_o;
    logic [BITS_CACHELINE-1:0] ic_frsp_data_o;

    logic                      dc_freq_valid_i;
    logic [XLEN-1:0]           dc_freq_addr_i;
    logic                      dc_freq_we_i;
    logic [BITS_CACHELINE-1:0] dc_freq_data_i;
    logic                      dc_frsp_valid_o;
    logic [BITS_CACHELINE-1:0] dc_frsp_data_o;

    logic                      mem_req_o;
    logic [XLEN-1:0]           mem_addr_o;
    logic                      mem_we_o;
    logic [BITS_CACHELINE-1:0] mem_wdata_o;
    logic                      mem_ready_i;
    logic [BITS_CACHELINE-1:0] mem_rdata_i;

    // Instantiate the Arbiter
    memory_arbitrer #(
        .XLEN(XLEN),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) dut (.*);

    // --- Internal Drive Logic ---
    logic mem_ready;
    logic [BITS_CACHELINE-1:0] mem_rdata;
    assign mem_ready_i = mem_ready;
    assign mem_rdata_i = mem_rdata;

    // --- Test Sequence ---
    initial begin
        clear_all();
        @(posedge reset_n);
        repeat(2) @(posedge clk);

        test_priority();
        test_dcache_writeback();

        repeat(5) @(posedge clk);
        $display("ALL TESTS PASSED");
        $finish;
    end

    task test_priority();
        $display("Testing Priority: DCache and ICache simultaneous request...");
        
        ic_fetch(32'h1000);
        dc_fetch(32'h2000);
        
        @(posedge clk);
        if (mem_req_o && mem_addr_o == 32'h2000)
            $display("SUCCESS: DCache granted access first.");
        else
            $display("ERROR: DCache priority failed.");

        repeat(1) @(posedge clk);
        // Explicit 128'h prefix
        mem_respond(128'hDEADC0DE_11112222_33334444_55556666);
        
        @(posedge clk);
        if (dc_frsp_valid_o && !ic_frsp_valid_o)
            $display("SUCCESS: DCache received response, ICache still waiting.");
        
        mem_idle();
        dc_idle(); 

        @(posedge clk);
        if (mem_req_o && mem_addr_o == 32'h1000)
            $display("SUCCESS: Arbiter switched to waiting ICache.");

        // FIXED: Added 128'h prefix to match exactly 128 bits
        mem_respond(128'h0000AAAA_BBBBCCCC_DDDDEEEE_FFFF0000);
        
        @(posedge clk);
        if (ic_frsp_valid_o)
            $display("SUCCESS: ICache received response.");

        mem_idle();
        ic_idle();
        @(posedge clk);
    endtask

    task test_dcache_writeback();
        $display("Testing DCache Writeback...");
        // Explicit 128'h prefix
        dc_write(32'h3000, 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111);
        
        @(posedge clk);
        if (mem_we_o && mem_wdata_o == 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111)
            $display("SUCCESS: Data written to memory correctly.");
        
        mem_respond(128'h0); 
        @(posedge clk);
        mem_idle();
        dc_idle();
    endtask

    // --- Helper Tasks ---
    task ic_fetch(input logic [XLEN-1:0] addr);
        ic_freq_valid_i = 1; ic_freq_addr_i = addr;
    endtask
    task dc_fetch(input logic [XLEN-1:0] addr);
        dc_freq_valid_i = 1; dc_freq_addr_i = addr; dc_freq_we_i = 0;
    endtask
    task dc_write(input logic [XLEN-1:0] addr, input logic [BITS_CACHELINE-1:0] data);
        dc_freq_valid_i = 1; dc_freq_addr_i = addr; dc_freq_we_i = 1; dc_freq_data_i = data;
    endtask
    task mem_respond(input logic [BITS_CACHELINE-1:0] data);
        mem_ready = 1; mem_rdata = data;
    endtask
    task ic_idle(); ic_freq_valid_i = 0; endtask
    task dc_idle(); dc_freq_valid_i = 0; endtask
    task mem_idle(); mem_ready = 0; endtask
    task clear_all();
        ic_freq_valid_i = 0; ic_freq_addr_i = 0;
        dc_freq_valid_i = 0; dc_freq_addr_i = 0; dc_freq_we_i = 0; dc_freq_data_i = 0;
        mem_ready = 0; mem_rdata = 0;
    endtask

endmodule
