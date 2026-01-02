import rob_pkg::*;
// This module is instantiated by the top_tb_wrapper
module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam int XLEN = `XLEN;
    localparam int N_ENTRIES = `N_ENTRIES_ROB;

    issue_req_t issue_req_i;
    issue_rsp_t issue_rsp_o;
    complete_t  complete_emw_i;
    complete_t  complete_mul_i;
    commit_t    commit_o;
    commit_rf_t commit_rf_o;
    commit_sb_t commit_sb_o;
    cam_req_t   cam_req_rs1_i;
    cam_rsp_t   cam_rsp_rs1_o;
    cam_req_t   cam_req_rs2_i;
    cam_rsp_t   cam_rsp_rs2_o;

    // Instantiate the DUT
    rob #(
        .XLEN(XLEN),
        .N_ENTRIES(N_ENTRIES)
    ) dut (.*);

    rv_regfile #(
        .XLEN(XLEN),
        .NREG(32)
    ) regs_inst (
        .clk,
        .reset_n,
        .rs1_addr_i('0),
        .rs1_data_o(),
        .rs2_addr_i('0),
        .rs2_data_o(),
        .rd_addr_i(commit_rf_o.rd_addr),
        .rd_data_i(commit_rf_o.rd_data),
        .rd_we_i(commit_rf_o.rd_we)
    );

    int TIMEOUT_CYCLES;
    int DEFAULT_TIMEOUT_CYCLES = 1000;
    initial begin
        if ($value$plusargs("TIMEOUT_CYCLES=%d", TIMEOUT_CYCLES)) begin
            $display("Timeout set at %d cycles", TIMEOUT_CYCLES);
        end else begin
            TIMEOUT_CYCLES = DEFAULT_TIMEOUT_CYCLES;
            $warning("Timeout not set. Using default %d cycles", TIMEOUT_CYCLES);
        end

        // Test sequence
        noop();
        @(posedge reset_n);
        repeat(4) @(posedge clk);

        test_directed();
        // test_random(50);

        noop();
        @(posedge clk);
        $finish;
    end

    int cycle_count = 0;
    int commit_count = 0;
    always @(posedge clk) begin
        if (reset_n) begin
            ++cycle_count;
            // Count commited
            if (commit_o.valid) begin
                commit_count += 1;
            end
            if (cycle_count >= TIMEOUT_CYCLES) begin
                $fatal(1, "Test FAILED! Timeout reached", TIMEOUT_CYCLES);
            end
        end
    end

    task test_directed();
        robid_t robid1, robid2;
        issue('h80000000, 2, 0);
        robid1 = issue_rsp_o.robid;
        @(posedge clk);
        issue('h80000004, 3, 0);
        robid2 = issue_rsp_o.robid;
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
        complete_emw(robid2, 'hcafecafe, '0, 0);
        @(posedge clk);
        complete_emw(robid1, 'hfe0fe0fe, '0, 1); // xcpt!!!
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
        issue('h80000008, 8, 0);
        robid1 = issue_rsp_o.robid;
        @(posedge clk);
        issue('h8000000c, 13, 0);
        robid2 = issue_rsp_o.robid;
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
        complete_emw(robid2, 'hbeefbeef, '0, 0);
        @(posedge clk);
        complete_emw(robid1, 'hdeaddead, '0, 0);
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
    endtask

    typedef struct packed {
        int        delay;
        logic[4:0] rd;
        logic      is_st;
    } tb_issue_t;

    task test_random(input int total_ops);
        int n_issued;
        logic [XLEN-1:0] pc;
        tb_issue_t created[$];
        int issued[robid_t];

        // Create all ops to be issued
        for (int i = 0; i < total_ops; ++i) begin
            tb_issue_t tmp;
            tmp.delay = $urandom_range(5,20);
            if ($urandom_range(1,100) < 50) begin
                // store
                tmp.rd    = '0;
                tmp.is_st = 1;
            end else begin
                // reg op
                tmp.rd    = $urandom_range(0,31)[4:0];
                tmp.is_st = 0;
            end
            created.push_back(tmp);
        end

        n_issued   = 0;
        pc = 'h1000;
        forever begin
            noop();
            // Issue someone (if possible)
            if ((n_issued < total_ops) & issue_rsp_o.ready) begin
                robid_t robid;
                issue(pc, created[n_issued].rd, created[n_issued].is_st);
                robid = issue_rsp_o.robid;
                issued[robid] = created[n_issued].delay;
                ++n_issued;
                pc += 'h4;
            end
            // Complete inflight ops
            foreach (issued[robid]) begin
                if (issued[robid] > 0) begin
                    issued[robid] -= 1;
                end else begin
                    complete_emw(robid, $urandom(), $urandom()[2:0], 0);
                    issued.delete(robid);
                end
            end
            // Peek CAM
            if ($urandom_range(1,100) < 50) begin
                peek_rs1($urandom_range(0,31)[4:0]);
            end
            if ($urandom_range(1,100) < 50) begin
                peek_rs2($urandom_range(0,31)[4:0]);
            end
            // Advance sim time
            @(posedge clk);
            // Check if all ops have committed
            if (commit_count >= total_ops) break;
        end
    endtask

    task issue (
        input logic[XLEN-1:0] pc,
        input logic[4:0] rd,
        input logic is_st
    );
        issue_req_i.valid   = 1;
        issue_req_i.pc      = pc;
        issue_req_i.rd_we   = ~is_st;
        issue_req_i.rd_addr = rd;
        issue_req_i.is_st   = is_st;
    endtask

    task complete_emw (
        input robid_t robid,
        input logic[XLEN-1:0] result,
        input sbid_t sbid,
        input logic xcpt
    );
        complete_emw_i.valid  = 1;
        complete_emw_i.robid  = robid;
        complete_emw_i.result = result;
        complete_emw_i.sbid   = sbid;
        complete_emw_i.xcpt   = xcpt;
    endtask

    task complete_mul (
        input robid_t robid,
        input logic[XLEN-1:0] result,
        input logic xcpt
    );
        complete_mul_i.valid  = 1;
        complete_mul_i.robid  = robid;
        complete_mul_i.result = result;
        complete_mul_i.sbid   = '0;
        complete_emw_i.xcpt   = xcpt;
    endtask

    task peek_rs1 (
        input logic [4:0] addr
    );
        cam_req_rs1_i.valid = 1;
        cam_req_rs1_i.addr  = addr;
    endtask

    task peek_rs2 (
        input logic [4:0] addr
    );
        cam_req_rs2_i.valid = 1;
        cam_req_rs2_i.addr  = addr;
    endtask

    task noop ();
        issue_req_i.valid    = 0;
        complete_emw_i.valid = 0;
        cam_req_rs1_i.valid    = 0;
        cam_req_rs2_i.valid    = 0;
    endtask

endmodule
