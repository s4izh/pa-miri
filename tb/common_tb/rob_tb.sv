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
        noop(issue_valid_i, complete_valid_i);
        @(posedge reset_n);
        @(posedge clk);

        test_directed();

        noop(issue_valid_i, complete_valid_i);
        @(posedge clk);
        $finish;
    end

    // - An issuing instructions generator
    // - A completing instructions generator
    // - A commiting instructions monitor

    task test_directed();
        rob_id_t robid1, robid2;
        issue('h80000000, 2,
            issue_valid_i, issue_pc_i, issue_rd_we_i, issue_rd_addr_i, issue_st_we_i, issue_st_data_i);
        @(posedge clk);
        robid1 = issue_robid_o;
        issue('h80000004, 3,
            issue_valid_i, issue_pc_i, issue_rd_we_i, issue_rd_addr_i, issue_st_we_i, issue_st_data_i);
        @(posedge clk);
        robid2 = issue_robid_o;
        noop(issue_valid_i, complete_valid_i);
        @(posedge clk);
        @(posedge clk);
        complete(robid2, 'hcafecafe,
            complete_valid_i, complete_rob_id_i, complete_rd_data_i);
        @(posedge clk);
        complete(robid1, 'hfe0fe0fe,
            complete_valid_i, complete_rob_id_i, complete_rd_data_i);
        @(posedge clk);
        noop(issue_valid_i, complete_valid_i);
        @(posedge clk);
        @(posedge clk);
        issue('h80000000, 8,
            issue_valid_i, issue_pc_i, issue_rd_we_i, issue_rd_addr_i, issue_st_we_i, issue_st_data_i);
        @(posedge clk);
        robid1 = issue_robid_o;
        issue('h80000004, 13,
            issue_valid_i, issue_pc_i, issue_rd_we_i, issue_rd_addr_i, issue_st_we_i, issue_st_data_i);
        @(posedge clk);
        robid2 = issue_robid_o;
        noop(issue_valid_i, complete_valid_i);
        @(posedge clk);
        @(posedge clk);
        complete(robid2, 'hcafecafe,
            complete_valid_i, complete_rob_id_i, complete_rd_data_i);
        @(posedge clk);
        complete(robid1, 'hfe0fe0fe,
            complete_valid_i, complete_rob_id_i, complete_rd_data_i);
        @(posedge clk);
        noop(issue_valid_i, complete_valid_i);
        @(posedge clk);
        @(posedge clk);
    endtask

    task issue (
        input logic[XLEN-1:0] pc,
        input logic[4:0] rd,

        // output robid_t robid;
        output logic            issue_valid_i,
        output logic [XLEN-1:0] issue_pc_i,
        output logic            issue_rd_we_i,
        output logic [4:0]      issue_rd_addr_i,
        output logic            issue_st_we_i,
        output logic [XLEN-1:0] issue_st_data_i
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

        output logic            complete_valid_i,
        output rob_id_t         complete_rob_id_i,
        output logic [XLEN-1:0] complete_rd_data_i
    );
        complete_valid_i    = 1;
        complete_rob_id_i   = robid;
        complete_rd_data_i  = result;
    endtask

    task noop (
        output logic issue_valid_i,
        output logic complete_valid_i
    );
        issue_valid_i = 0;
        complete_valid_i = 0;
    endtask

endmodule
