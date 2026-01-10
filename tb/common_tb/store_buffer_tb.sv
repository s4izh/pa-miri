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

    store_buffer #(
        .DEPTH(DEPTH), 
        .DRAIN_THRESHOLD(6) 
    ) dut (.*);

    initial begin
        init_signals();
        wait(reset_n == 1'b1);
        repeat(5) @(negedge clk);

        $display("--- Starting EXTENSIVE Store Buffer Tests ---");

        test_forwarding_logic();
        test_drain_threshold();
        test_fence_behavior();
        test_squash_and_recovery();
        test_wrap_around();
        
        $display("--- ALL EXTENSIVE TESTS PASSED ---");
        $finish;
    end

    // =========================================================================
    // TEST CASES
    // =========================================================================

    task automatic test_forwarding_logic();
        logic [SB_IDX_W-1:0] id;
        $display("[TEST] Forwarding Logic...");

        // perfect match hit
        alloc_and_exec(id, 32'h1000, 32'hCAFEBABE, MEMOP_WIDTH_32);
        check_forward(32'h1000, MEMOP_WIDTH_32, id+1'b1, 1'b1, 1'b0, 32'hCAFEBABE, "Perfect Word Hit");

        // perfect match but data pending (stall)
        alloc_only(id);
        check_forward(32'h0, MEMOP_WIDTH_32, id+1'b1, 1'b0, 1'b1, 32'h0, "Data Pending Stall");
        execute_pulse(id, 32'h2000, 32'h1234, MEMOP_WIDTH_32);

        // partial Overlap (stall) 
        alloc_and_exec(id, 32'h3000, 32'hAAAA_BBBB, MEMOP_WIDTH_32);
        check_forward(32'h3001, MEMOP_WIDTH_8, id+1'b1, 1'b0, 1'b1, 32'h0, "Partial Overlap Stall");

        clear_buffer();
    endtask

    task automatic test_drain_threshold();
        logic [SB_IDX_W-1:0] ids[6];
        $display("[TEST] Drain Threshold (Lazy Draining)...");

        for(int i=0; i<5; i++) begin
            alloc_and_exec(ids[i], 32'h400+i*4, 32'(i+1), MEMOP_WIDTH_32);
            commit_pulse(ids[i]);
        end

        #1;
        if (dut.state != 0) begin $display("FAIL: Draining started too early"); $finish; end

        alloc_and_exec(ids[5], 32'h414, 32'h6, MEMOP_WIDTH_32);
        commit_pulse(ids[5]);
        
        #1;
        if (dut.state == 0) begin $display("FAIL: Draining should have started"); $finish; end
        wait_for_empty();
    endtask

    task automatic test_fence_behavior();
        logic [SB_IDX_W-1:0] id;
        $display("[TEST] FENCE Behavior...");
        alloc_and_exec(id, 32'h500, 32'hF00D, MEMOP_WIDTH_32);
        commit_pulse(id);
        
        fence_i = 1;
        wait_for_empty();
        fence_i = 0;
        $display("  Pass: FENCE forced drain.");
    endtask

    task automatic test_squash_and_recovery();
        logic [SB_IDX_W-1:0] id_safe, id_spec;
        $display("[TEST] Squash (DIV Exception Scenario)...");

        alloc_and_exec(id_safe, 32'h600, 32'h600, MEMOP_WIDTH_32);
        commit_pulse(id_safe);

        alloc_and_exec(id_spec, 32'h700, 32'h700, MEMOP_WIDTH_32);
        
        $display("  Triggering FLUSH...");
        @(negedge clk); flush_i = 1; @(negedge clk); flush_i = 0;
        @(posedge clk); #1;

        if (32'(dut.count) != 32'h1 || 32'(dut.tail_ptr) != 32'h1) begin
            $display("FAIL: Squash pointers incorrect! Count:%0d Tail:%0d", dut.count, dut.tail_ptr);
            $finish;
        end
        $display("  Pass: Squash correctly reset tail_ptr.");
        clear_buffer();
    endtask

    task automatic test_wrap_around();
        logic [SB_IDX_W-1:0] id;
        $display("[TEST] Circular Wrap-around...");
        clear_buffer(); 
        
        for(int i=0; i<8; i++) begin
            alloc_and_exec(id, 32'h800+i*4, 32'(i), MEMOP_WIDTH_32);
            commit_pulse(id);
        end
        fence_i = 1; wait_for_empty(); fence_i = 0;
        
        for(int i=0; i<4; i++) alloc_and_exec(id, 32'h900+i*4, 32'(i), MEMOP_WIDTH_32);
        if (32'(dut.tail_ptr) != 32'h4) begin $display("FAIL: Wrap around error"); $finish; end
        $display("  Pass: Wrap-around verified.");
        clear_buffer();
    endtask

    // =========================================================================
    // HELPER TASKS - Directions explicitly defined
    // =========================================================================
    task automatic init_signals();
        alloc_en_i = 0; creq_en_i = 0; commit_en_i = 0; 
        fence_i = 0; flush_i = 0; dreq_ready_i = 1;
        ld_addr_i = 0; ld_width_i = MEMOP_WIDTH_32; ld_age_tag_i = 0;
    endtask

    task automatic alloc_only(output logic [SB_IDX_W-1:0] id);
        @(negedge clk);
        alloc_en_i = 1;
        id = alloc_idx_o;
        @(posedge clk); 
        #1;
        alloc_en_i = 0;
    endtask

    task automatic execute_pulse(input logic [SB_IDX_W-1:0] id, input logic [31:0] a, input logic [31:0] d, input memop_width_e w);
        @(negedge clk);
        creq_en_i = 1; creq_idx_i = id; creq_addr_i = a; creq_data_i = d; creq_width_i = w;
        @(posedge clk); 
        #1;
        creq_en_i = 0;
    endtask

    task automatic alloc_and_exec(output logic [SB_IDX_W-1:0] id, input logic [31:0] a, input logic [31:0] d, input memop_width_e w);
        alloc_only(id);
        execute_pulse(id, a, d, w);
    endtask

    task automatic commit_pulse(input logic [SB_IDX_W-1:0] id);
        @(negedge clk);
        commit_en_i = 1; commit_idx_i = id; 
        @(posedge clk); 
        #1;
        commit_en_i = 0;
    endtask

    task automatic check_forward(input logic [31:0] addr, input memop_width_e w, input logic [SB_IDX_W-1:0] tag, 
                                 input logic hit, input logic stall, input logic [31:0] data, input string msg);
        ld_addr_i = addr; ld_width_i = w; ld_age_tag_i = tag;
        #1;
        if (ld_hit_o !== hit || ld_stall_o !== stall || (hit && ld_data_o !== data)) begin
            $display("FAIL [%s]: Hit:%b(Exp:%b) Stall:%b(Exp:%b) Data:%h(Exp:%h)", 
                      msg, ld_hit_o, hit, ld_stall_o, stall, ld_data_o, data);
            $finish;
        end
        $display("  Pass: %s", msg);
    endtask

    task automatic wait_for_empty();
        int timeout = 0;
        while(!sb_empty_o && timeout < 200) begin @(posedge clk); timeout++; end
        if (timeout >= 200) begin $display("ERROR: Timeout!"); $finish; end
    endtask

    task automatic clear_buffer();
        for(int i=0; i<DEPTH; i++) begin
            if (dut.buffer[i].allocated) commit_pulse(i[SB_IDX_W-1:0]);
        end
        fence_i = 1; wait_for_empty(); fence_i = 0;
    endtask

endmodule
