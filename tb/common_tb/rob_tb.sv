// This module is instantiated by the top_tb_wrapper
module tb (
    input logic clk,
    input logic reset_n
);
    // Parameters
    localparam XLEN = 32;
    localparam N_ENTRIES = 8;

    parameter type rob_id_t = logic[$clog2(N_ENTRIES)-1:0];

    // DUT signals
    // Issue interface
    logic            issue_valid_i;
    logic [XLEN-1:0] issue_pc_i;
    logic            issue_rd_we_i;
    logic [4:0]      issue_rd_addr_i;
    logic            issue_st_we_i;
    logic [XLEN-1:0] issue_st_data_i;
    logic            issue_robid_valid_o;
    rob_id_t         issue_robid_o;
    // Complete interface
    logic            complete_valid_i;
    rob_id_t         complete_rob_id_i;
    logic [XLEN-1:0] complete_rd_data_i;
    // Commit interface
    logic            commit_we_o;
    logic [4:0]      commit_rd_addr_o;
    logic [XLEN-1:0] commit_rd_data_o;

    // Instantiate the DUT
    rob #(
        .XLEN(XLEN),
        .N_ENTRIES(N_ENTRIES)
    ) dut (.*);

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

    // - An issuing instructions generator
    // - A completing instructions generator
    // - A commiting instructions monitor

    task test_directed();
        rob_id_t robid1, robid2;
        issue('h80000000, 2);
        @(posedge clk);
        robid1 = issue_robid_o;
        issue('h80000004, 3);
        @(posedge clk);
        robid2 = issue_robid_o;
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
        @(posedge clk);
        robid1 = issue_robid_o;
        issue('h8000000c, 13);
        @(posedge clk);
        robid2 = issue_robid_o;
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
        input logic[4:0] rd,
    );
        issue_valid_i       = 1;
        issue_pc_i          = pc;
        issue_rd_we_i       = 1;
        issue_rd_addr_i     = rd;
        issue_st_we_i       = 0;
    endtask

    task complete (
        input rob_id_t robid,
        input logic[XLEN-1:0] result,
    );
        complete_valid_i    = 1;
        complete_rob_id_i   = robid;
        complete_rd_data_i  = result;
    endtask

    task noop ();
        issue_valid_i = 0;
        complete_valid_i = 0;
    endtask

endmodule
