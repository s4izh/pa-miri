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

    // Test sequence
    initial begin
        noop();
        @(posedge reset_n);
        repeat(4) @(posedge clk);

        test_directed();

        noop();
        @(posedge clk);
        $finish;
    end

    // - An issuing instructions generator
    // - A completing instructions generator
    // - A commiting instructions monitor

    task test_directed();
        robid_t robid1, robid2;
        issue('h80000000, 2);
        robid1 = issue_rsp_o.robid;
        @(posedge clk);
        issue('h80000004, 3);
        robid2 = issue_rsp_o.robid;
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
        complete(robid2, 'hcafecafe);
        @(posedge clk);
        complete(robid1, 'hfe0fe0fe);
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
        issue('h80000008, 8);
        robid1 = issue_rsp_o.robid;
        @(posedge clk);
        issue('h8000000c, 13);
        robid2 = issue_rsp_o.robid;
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
        complete(robid2, 'hbeefbeef);
        @(posedge clk);
        complete(robid1, 'hdeaddead);
        @(posedge clk);
        noop();
        @(posedge clk);
        @(posedge clk);
    endtask

    task issue (
        input logic[XLEN-1:0] pc,
        input logic[4:0] rd
    );
        issue_req_i.valid   = 1;
        issue_req_i.pc      = pc;
        issue_req_i.rd_we   = 1;
        issue_req_i.rd_addr = rd;
        issue_req_i.is_st   = 0;
    endtask

    task complete (
        input robid_t robid,
        input logic[XLEN-1:0] result
    );
        complete_emw_i.valid  = 1;
        complete_emw_i.robid  = robid;
        complete_emw_i.result = result;
        complete_emw_i.sbid   = '0; // FIXME
    endtask

    task noop ();
        issue_req_i.valid    = 0;
        complete_emw_i.valid = 0;
    endtask

endmodule
