// import rv_datapath_pkg::*;
import memory_controller_pkg::*;

module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam int XLEN   = 32;
    localparam int DEPTH  = 8;
    localparam int SB_IDX_W = $clog2(DEPTH);

    // --- DUT Signals ---
    logic                alloc_en_i;
    logic [SB_IDX_W-1:0] alloc_idx_o;
    logic                sb_full_o;

    logic                creq_en_i;
    logic [SB_IDX_W-1:0] creq_idx_i;
    logic [XLEN-1:0]     creq_addr_i;
    logic [XLEN-1:0]     creq_data_i;
    memop_width_e        creq_width_i;

    logic                commit_en_i;
    logic [SB_IDX_W-1:0] commit_idx_i;

    logic [XLEN-1:0]     ld_addr_i;
    memop_width_e        ld_width_i;
    logic [SB_IDX_W-1:0] ld_age_tag_i;
    logic                ld_hit_o;
    logic                ld_stall_o;
    logic [XLEN-1:0]     ld_data_o;

    logic              dreq_valid_o;
    logic              dreq_ready_i; 
    logic [XLEN-1:0]   dreq_addr_o;
    logic [XLEN-1:0]   dreq_data_o;
    logic              dreq_we_o;      
    memop_width_e      dreq_width_o;

    // --- DUT Instantiation ---
    store_buffer #(
        .XLEN(XLEN),
        .DEPTH(DEPTH),
        .DRAIN_THRESHOLD(6)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .* // Connects remaining signals by name
    );

    // --- Test Execution ---
    initial begin
        // 1. Initialize signals to 0
        init_signals();

        // 2. Wait for the wrapper to release reset
        wait(reset_n == 1'b1);
        repeat(5) @(posedge clk);

        $display("--- [TB] Starting Store Buffer Directed Tests ---");

        // Run Scenarios
        test_directed_forwarding();
        test_directed_hazard();
        test_directed_full_drain();

        // 3. Proper Termination
        repeat(20) @(posedge clk);
        $display("--- [TB] All Tests Passed ---");
        $finish; 
    end

    // --- Tasks: Test Scenarios ---

    task test_directed_forwarding();
        logic [SB_IDX_W-1:0] id0;
        $display("[Test] Forwarding: Store Word then Load Word");
        
        allocate(id0);
        execute(id0, 'h100, 'hABCDEF01, MEMOP_WIDTH_32);
        
        // Age tag is id+1 because load is younger than store
        check_load('h100, MEMOP_WIDTH_32, id0 + 1'b1);

        if (ld_hit_o && ld_data_o == 'hABCDEF01)
            $display("  Pass: Forwarded correctly");
        else begin
            $display("  Fail: Forwarding Error (Hit: %b, Data: %h)", ld_hit_o, ld_data_o);
            $finish;
        end
        noop();
    endtask

    task test_directed_hazard();
        logic [SB_IDX_W-1:0] id0;
        $display("[Test] Hazard: Overlapping addresses must stall");

        allocate(id0);
        execute(id0, 'h200, 'h11223344, MEMOP_WIDTH_32);
        
        // Load Byte at 0x201 overlaps with Word at 0x200
        check_load('h201, MEMOP_WIDTH_8, id0 + 1'b1);

        if (ld_stall_o)
            $display("  Pass: Stalled on partial overlap");
        else begin
            $display("  Fail: Did not stall on hazard");
            $finish;
        end

        // Commit and wait for the stall to clear via drain
        commit(id0);
        while(ld_stall_o) @(posedge clk);
        $display("  Pass: Stall cleared after store commit/drain");
        noop();
    endtask

    task test_directed_full_drain();
        logic [SB_IDX_W-1:0] ids [DEPTH];
        $display("[Test] Buffer Full Logic and Draining");

        dreq_ready_i = 0; // Simulate busy cache
        for (int i=0; i<DEPTH; i++) begin
            allocate(ids[i]);
            execute(ids[i], 'h400+(i*4), i+100, MEMOP_WIDTH_32);
        end

        if (sb_full_o)
            $display("  Pass: Buffer reported full correctly");
        else begin
            $display("  Fail: Buffer should be full");
            $finish;
        end

        // Release cache and commit all to trigger drain
        dreq_ready_i = 1;
        for (int i=0; i<DEPTH; i++) commit(ids[i]);

        // Wait until count reaches 0
        while (dut.count != 0) @(posedge clk);
        $display("  Pass: All stores drained successfully");
        noop();
    endtask

    // --- Helper Tasks ---

    task init_signals();
        alloc_en_i   = 0;
        creq_en_i    = 0;
        commit_en_i  = 0;
        ld_addr_i    = 0;
        ld_width_i   = MEMOP_WIDTH_32;
        ld_age_tag_i = 0;
        dreq_ready_i = 1;
    endtask

    task allocate(output logic [SB_IDX_W-1:0] idx);
        alloc_en_i = 1;
        @(posedge clk);
        #1 idx = alloc_idx_o;
        alloc_en_i = 0;
    endtask

    task execute(logic [SB_IDX_W-1:0] idx, logic [XLEN-1:0] addr, logic [XLEN-1:0] data, memop_width_e w);
        creq_en_i    = 1;
        creq_idx_i   = idx;
        creq_addr_i  = addr;
        creq_data_i  = data;
        creq_width_i = w;
        @(posedge clk);
        creq_en_i    = 0;
    endtask

    task commit(logic [SB_IDX_W-1:0] idx);
        commit_en_i  = 1;
        commit_idx_i = idx;
        @(posedge clk);
        commit_en_i  = 0;
    endtask

    task check_load(logic [XLEN-1:0] addr, memop_width_e w, logic [SB_IDX_W-1:0] tag);
        ld_addr_i    = addr;
        ld_width_i   = w;
        ld_age_tag_i = tag;
        #1; // Wait for combinational logic to update
    endtask

    task noop();
        alloc_en_i  = 0;
        creq_en_i   = 0;
        commit_en_i = 0;
        @(posedge clk);
    endtask

endmodule
