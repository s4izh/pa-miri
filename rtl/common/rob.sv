// https://www.youtube.com/watch?v=9yo3yhUijQs
import rob_pkg::*;
import store_buffer_pkg::*;

module rob #(
    parameter int XLEN = `XLEN,
    parameter int N_ENTRIES = `ROB_N_ENTRIES
) (
    input logic clk,
    input logic reset_n,
    // Request to issue new instruction
    input  issue_req_t     issue_req_i,
    input  issue_req_csr_t issue_req_csr_i,
    output issue_rsp_t     issue_rsp_o,
    // Complete instruction from alu-memory fu
    input  complete_t      complete_alumem_i,
    // Complete instruction from multiply fu
    input  complete_t      complete_muldiv_i,
    // Complete instruction from csr fu
    input  complete_csr_t  complete_csr_i,
    // Commit xcpt control
    input  logic           can_commit_xcpt_i,
    // Commit general (general info)
    output commit_t        commit_o,
    // Commit to register file
    output commit_rf_t     commit_rf_o,
    // Commit to store_buffer
    output commit_sb_t     commit_sb_o,
    // Commit to store_buffer
    output commit_csr_t    commit_csr_o,
    // Peek youngest rs1 value
    input  cam_req_t       cam_req_rs1_i,
    output cam_rsp_t       cam_rsp_rs1_o,
    // Peek youngest rs2 value
    input  cam_req_t       cam_req_rs2_i,
    output cam_rsp_t       cam_rsp_rs2_o,
    // Peek youngest csr value
    input  cam_req_csr_t   cam_req_csr_i,
    output cam_rsp_t       cam_rsp_csr_o
);
    // Define a type for a reorder buffer entry
    typedef struct packed {
        logic [XLEN-1:0] pc;
        logic [XLEN-1:0] dbg_ins;
        // rf
        logic            rd_we;
        logic [4:0]      rd_addr;
        // sb
        logic            is_st;
        sbid_t           sbid;
        // csr
        logic            csr_we;
        logic [11:0]     csr_addr;
        // complete
        logic            complete;
        logic [XLEN-1:0] rd_result;
        logic [XLEN-1:0] csr_result;
        logic            xcpt;
    } rob_entry_t;

    // Tail points to the youngest entry
    // Head points to the oldest entry
    // Therefore, instructions are instroduced through the tail,
    // and completed through the head
    //      ........
    //    | rob_id 3 | <- head_q
    //    | rob_id 4 |
    //    | rob_id 5 |
    //    | rob_id 6 |
    //    | rob_id 7 | <- tail_q
    //      ........
    robid_t tail_d, tail_q, head_d, head_q;
    rob_entry_t [N_ENTRIES-1:0] entries;
    logic empty, full;
    assign empty = (tail_q == head_q);
    assign full = (tail_q+1 == head_q) | ((&tail_q) & (head_q == '0));

    logic committing_xcpt;
    logic committing_head_q, issuing_tail_q;
    assign committing_head_q = entries[head_q].complete & ~empty & ((entries[head_q].xcpt & can_commit_xcpt_i) | ~entries[head_q].xcpt);
    assign committing_xcpt   = committing_head_q & entries[head_q].xcpt;
    assign issuing_tail_q    = ~committing_xcpt & issue_req_i.valid & ~full;

    // Control head_q and tail_q ff
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            head_q <= '0;
            tail_q <= '0;
        end else begin
            head_q <= head_d;
            tail_q <= tail_d;
        end
    end

    // Control head_d
    always_comb begin
        head_d = head_q;
        if (committing_head_q) begin
            head_d = head_q + 1;
        end
    end

    // Control tail_d
    always_comb begin
        tail_d = tail_q;
        if (committing_xcpt) begin
            tail_d = head_d;
        end else if (issue_req_i.valid & ~full) begin
            tail_d = tail_q + 1;
        end
    end

    assign issue_rsp_o.robid = tail_q;
    assign issue_rsp_o.ready = ~full;

    // Issue and complete logic
    always_ff @(posedge clk) begin
        // Issue
        if (issuing_tail_q) begin
            entries[tail_q].pc         <= issue_req_i.pc;
            entries[tail_q].dbg_ins    <= issue_req_i.dbg_ins;
            entries[tail_q].rd_we      <= issue_req_i.rd_we;
            entries[tail_q].rd_addr    <= issue_req_i.rd_addr;
            entries[tail_q].is_st      <= issue_req_i.is_st;
            entries[tail_q].csr_we     <= issue_req_csr_i.csr_we;
            entries[tail_q].csr_addr   <= issue_req_csr_i.csr_addr;
            entries[tail_q].sbid       <= '0;
            entries[tail_q].complete   <= issue_req_i.xcpt;
            entries[tail_q].rd_result  <= '0;
            entries[tail_q].csr_result <= '0;
            entries[tail_q].xcpt       <= issue_req_i.xcpt;
        end
        // Complete alumem
        if (complete_alumem_i.valid) begin
            entries[complete_alumem_i.robid].complete <= 1;
            entries[complete_alumem_i.robid].rd_result <= complete_alumem_i.result;
            entries[complete_alumem_i.robid].xcpt      <= complete_alumem_i.xcpt;
            entries[complete_alumem_i.robid].sbid      <= complete_alumem_i.sbid;
        end
        // Complete muldiv
        if (complete_muldiv_i.valid) begin
            entries[complete_muldiv_i.robid].complete  <= 1;
            entries[complete_muldiv_i.robid].rd_result <= complete_muldiv_i.result;
            entries[complete_muldiv_i.robid].xcpt      <= complete_muldiv_i.xcpt;
            entries[complete_muldiv_i.robid].sbid      <= complete_muldiv_i.sbid;
        end
        // Complete csr
        if (complete_csr_i.valid) begin
            entries[complete_csr_i.robid].complete     <= 1;
            entries[complete_csr_i.robid].rd_result    <= complete_csr_i.rd_result;
            entries[complete_csr_i.robid].csr_result   <= complete_csr_i.csr_result;
            entries[complete_csr_i.robid].xcpt         <= complete_csr_i.xcpt;
        end
    end

    // Commit logic
    always_comb begin
        commit_o     = '0;
        commit_rf_o  = '0;
        commit_sb_o  = '0;
        commit_csr_o = '0;
        commit_o.dbg_robid = head_q;
        commit_o.dbg_ins   = entries[head_q].dbg_ins;
        commit_o.pc        = entries[head_q].pc;
        if (committing_head_q) begin
            commit_o.valid  = 1;
            commit_o.xcpt   = entries[head_q].xcpt;
            if (~entries[head_q].xcpt) begin
                if (entries[head_q].is_st) begin
                    commit_sb_o.valid = 1;
                    commit_sb_o.sbid  = entries[head_q].sbid;
                end else begin
                    if (entries[head_q].csr_we) begin
                        commit_csr_o.csr_we   = entries[head_q].csr_we;
                        commit_csr_o.csr_addr = entries[head_q].csr_addr;
                        commit_csr_o.csr_data = entries[head_q].csr_result;
                    end
                    commit_rf_o.rd_we   = entries[head_q].rd_we;
                    commit_rf_o.rd_addr = entries[head_q].rd_addr;
                    commit_rf_o.rd_data = entries[head_q].rd_result;
                end
            end
        end
    end

    // CAM lookup for younger instructions to use my values
    // RS1
    always_comb begin
        logic   found;
        robid_t found_robid;
        // Default
        cam_rsp_rs1_o = '0;

        found       = 0;
        found_robid = '0;
        if (~empty & (cam_req_rs1_i.addr != '0)) begin
            // Go from head (oldest) til tail-1 (youngest) and overwrite the
            // value with the youngest valid entry
            for (robid_t i = head_q; i != tail_q; ++i) begin
                if ((entries[i].rd_addr == cam_req_rs1_i.addr) & ~entries[i].xcpt & entries[i].rd_we) begin
                    found = 1;
                    found_robid = i;
                end
            end
            // Final asssign
            cam_rsp_rs1_o.valid    = found;
            cam_rsp_rs1_o.complete = entries[found_robid].complete;
            cam_rsp_rs1_o.value    = entries[found_robid].rd_result;
            cam_rsp_rs1_o.robid    = found_robid;
        end
    end
    // RS2
    always_comb begin
        logic   found;
        robid_t found_robid;
        // Default
        cam_rsp_rs2_o = '0;

        found       = 0;
        found_robid = '0;
        if (~empty & (cam_req_rs2_i.addr != '0)) begin
            // Go from head (oldest) til tail-1 (youngest) and overwrite the
            // value with the youngest valid entry
            for (robid_t i = head_q; i != tail_q; ++i) begin
                if ((entries[i].rd_addr == cam_req_rs2_i.addr) & ~entries[i].xcpt & entries[i].rd_we) begin
                    found = 1;
                    found_robid = i;
                end
            end
            // Final asssign
            cam_rsp_rs2_o.valid    = found;
            cam_rsp_rs2_o.complete = entries[found_robid].complete;
            cam_rsp_rs2_o.value    = entries[found_robid].rd_result;
            cam_rsp_rs2_o.robid    = found_robid;
        end
    end
    // CSR
    always_comb begin
        logic   found;
        robid_t found_robid;
        // Default
        cam_rsp_csr_o = '0;

        found       = 0;
        found_robid = '0;
        if (~empty) begin
            // Go from head (oldest) til tail-1 (youngest) and overwrite the
            // value with the youngest valid entry
            for (robid_t i = head_q; i != tail_q; ++i) begin
                if ((entries[i].csr_addr == cam_req_csr_i.addr) & ~entries[i].xcpt & entries[i].csr_we) begin
                    found = 1;
                    found_robid = i;
                end
            end
            // Final asssign
            cam_rsp_csr_o.valid    = found;
            cam_rsp_csr_o.complete = entries[found_robid].complete;
            cam_rsp_csr_o.value    = entries[found_robid].csr_result;
            cam_rsp_csr_o.robid    = found_robid;
        end
    end

endmodule
