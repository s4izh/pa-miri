import memory_controller_pkg::*;

module tb (
    input logic clk,
    input logic reset_n
);
    localparam int DEPTH = 8;
    localparam int SB_IDX_W = $clog2(DEPTH);

    // DUT Signals
    logic alloc_en_i, sb_full_o, sb_empty_o, creq_en_i, commit_en_i, fence_i, flush_i;
    logic [SB_IDX_W-1:0] alloc_idx_o, creq_idx_i, commit_idx_i, ld_age_tag_i;
    logic [31:0] creq_addr_i, creq_data_i, ld_addr_i, ld_data_o, dreq_addr_o, dreq_data_o;
    memop_width_e creq_width_i, ld_width_i, dreq_width_o;
    logic ld_hit_o, ld_stall_o, dreq_valid_o, dreq_ready_i, dreq_we_o;

    store_buffer #(.DEPTH(DEPTH), .DRAIN_THRESHOLD(6)) dut (.*);

    // Drive everything on negedge to avoid races with the posedge-triggered DUT
    initial begin
        init_signals();
        wait(reset_n == 1'b1);
        repeat(5) @(negedge clk); 

        $display("--- Starting Robust Store Buffer Tests ---");

        test_forwarding_sequence();
        test_squash_sequence();
        
        $display("--- All Tests Passed ---");
        $finish;
    end

    task automatic init_signals();
        alloc_en_i = 0; creq_en_i = 0; commit_en_i = 0; 
        fence_i = 0; flush_i = 0; dreq_ready_i = 1;
        ld_addr_i = 0; ld_width_i = MEMOP_WIDTH_32; ld_age_tag_i = 0;
    endtask

    task automatic test_forwarding_sequence();
        logic [SB_IDX_W-1:0] id;
        
        // 1. Allocate
        @(negedge clk);
        alloc_en_i = 1;
        #1; id = alloc_idx_o;
        @(negedge clk);
        alloc_en_i = 0;

        // 2. Execute
        creq_en_i    = 1;
        creq_idx_i   = id;
        creq_addr_i  = 32'h100;
        creq_data_i  = 32'hABCDEF;
        creq_width_i = MEMOP_WIDTH_32;
        @(negedge clk);
        creq_en_i    = 0;

        // 3. Forwarding Check (Combinatorial)
        ld_addr_i    = 32'h100;
        ld_width_i   = MEMOP_WIDTH_32;
        ld_age_tag_i = id + 1'b1;
        #1; 
        if (ld_hit_o && ld_data_o == 32'hABCDEF) $display("  Forwarding Hit: Pass");
        else begin $display("  Forwarding Fail! Hit:%b Stall:%b Data:%h", ld_hit_o, ld_stall_o, ld_data_o); $finish; end

        // 4. Commit
        commit_en_i  = 1;
        commit_idx_i = id;
        @(negedge clk);
        commit_en_i  = 0;

        // 5. Drain
        fence_i = 1;
        wait_for_empty();
        fence_i = 0;
        $display("  Drain: Pass");
    endtask

    task automatic test_squash_sequence();
        logic [SB_IDX_W-1:0] id_spec;
        $display("[TB] Testing Squash...");

        @(negedge clk);
        alloc_en_i = 1;
        id_spec = alloc_idx_o;
        @(negedge clk);
        alloc_en_i = 0;
        
        creq_en_i = 1; creq_idx_i = id_spec; creq_addr_i = 32'h500; creq_data_i = 32'hDEAD;
        creq_width_i = MEMOP_WIDTH_32;
        @(negedge clk);
        creq_en_i = 0;

        // Squash
        flush_i = 1;
        @(negedge clk);
        flush_i = 0;
        
        #1;
        if (ld_hit_o) begin $display("  Squash Fail: Store still visible!"); $finish; end
        else $display("  Squash Success: Store erased.");
    endtask

    task automatic wait_for_empty();
        int timeout = 0;
        while(!sb_empty_o && timeout < 100) begin
            @(posedge clk);
            timeout++;
        end
        if (timeout >= 100) begin
            $display("ERROR: Timeout! Count is %0d, Head is %0d, CommitPtr is %0d", dut.count, dut.head, dut.commit_ptr);
            $finish;
        end
    endtask
endmodule
