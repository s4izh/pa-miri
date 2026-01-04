import memory_controller_pkg::*;

module tb (
    input logic clk,
    input logic reset_n
);
    localparam int DEPTH = 8;
    localparam int SB_IDX_W = $clog2(DEPTH);

    // DUT Signals
    logic alloc_en_i, sb_full_o, sb_empty_o, creq_en_i, commit_en_i, fence_i;
    logic [SB_IDX_W-1:0] alloc_idx_o, creq_idx_i, commit_idx_i, ld_age_tag_i;
    logic [31:0] creq_addr_i, creq_data_i, ld_addr_i, ld_data_o, dreq_addr_o, dreq_data_o;
    memop_width_e creq_width_i, ld_width_i, dreq_width_o;
    logic ld_hit_o, ld_stall_o, dreq_valid_o, dreq_ready_i, dreq_we_o;

    // Instantiate DUT
    store_buffer #( 
        .DEPTH(DEPTH), 
        .DRAIN_THRESHOLD(6) // Only drains automatically if count >= 6
    ) dut (.*);

    // Watchdog
    initial begin
        repeat(5000) @(posedge clk);
        $display("FATAL: Testbench timed out!");
        $finish;
    end

    initial begin
        init_signals();
        wait(reset_n == 1'b1);
        repeat(10) @(posedge clk);

        $display("--- Starting Tests ---");

        // Test 1: Forwarding (and use Fence to clear)
        test_forwarding_and_flush();

        // Test 2: Fill to 8/8 (This will trigger automatic drain)
        test_full_buffer_and_drain();
        
        $display("--- All Tests Completed Successfully ---");
        repeat(50) @(posedge clk);
        $finish;
    end

    // --- Tasks ---

    task automatic init_signals();
        alloc_en_i = 0; creq_en_i = 0; commit_en_i = 0; fence_i = 0;
        ld_addr_i = 0; ld_width_i = MEMOP_WIDTH_32; dreq_ready_i = 1;
    endtask

    task automatic test_forwarding_and_flush();
        logic [SB_IDX_W-1:0] id;
        $display("[TB] Test Forwarding...");
        alloc_pulse(id);
        execute_pulse(id, 'h100, 'hABCDEF, MEMOP_WIDTH_32);
        
        // Check forwarding
        ld_addr_i = 'h100; ld_age_tag_i = id + 1'b1;
        #1;
        if (ld_hit_o && ld_data_o == 'hABCDEF) $display("  Forwarding Pass.");
        else begin $display("  Forwarding Fail!"); $finish; end
        
        // To clear the buffer, we MUST commit AND either hit threshold or FENCE
        commit_pulse(id);
        
        $display("[TB] Store is committed but Lazy. Asserting FENCE to flush...");
        fence_i = 1;
        wait_for_empty();
        fence_i = 0;
        $display("  Buffer Flushed.");
    endtask

    task automatic test_full_buffer_and_drain();
        logic [SB_IDX_W-1:0] ids [DEPTH];
        $display("[TB] Filling buffer to 8/8 to trigger automatic drain...");
        
        dreq_ready_i = 0; // Busy cache - stop it from draining while we fill
        for (int i=0; i<DEPTH; i++) begin
            alloc_pulse(ids[i]);
            execute_pulse(ids[i], 'h400+i*4, i+1, MEMOP_WIDTH_32);
            commit_pulse(ids[i]); // Commit them all so they are ready to drain
        end

        #1;
        if (sb_full_o) $display("  Buffer Full detected (Count=8).");

        repeat(10) @(posedge clk); // Stay full for a bit so we can see it in waves
        
        $display("[TB] Releasing Cache Ready. Automatic drain should start (Count 8 > 6)...");
        dreq_ready_i = 1;
        
        wait_for_empty();
        $display("  Automatic Drain Pass.");
    endtask

    // --- Core Pulses ---

    task automatic alloc_pulse(output logic [SB_IDX_W-1:0] id);
        alloc_en_i = 1; @(posedge clk); #1 id = alloc_idx_o; alloc_en_i = 0;
    endtask

    task automatic execute_pulse(logic [SB_IDX_W-1:0] id, logic [31:0] a, logic [31:0] d, memop_width_e w);
        creq_en_i = 1; creq_idx_i = id; creq_addr_i = a; creq_data_i = d; creq_width_i = w;
        @(posedge clk); creq_en_i = 0;
    endtask

    task automatic commit_pulse(logic [SB_IDX_W-1:0] id);
        commit_en_i = 1; commit_idx_i = id; @(posedge clk); commit_en_i = 0;
    endtask

    task automatic wait_for_empty();
        int timeout = 0;
        // Wait for count to reach 0
        while(!sb_empty_o && timeout < 200) begin
            @(posedge clk);
            timeout++;
        end
        if (timeout >= 200) begin
            $display("ERROR: Timeout waiting for empty! Count is %0d, state is %0d", dut.count, dut.state);
            $finish;
        end
    endtask

endmodule
