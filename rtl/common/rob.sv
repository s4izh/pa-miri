// https://www.youtube.com/watch?v=9yo3yhUijQs
import rob_pkg::*;

module rob #(
    parameter int XLEN = `XLEN,
    parameter int N_ENTRIES = `N_ENTRIES_ROB
) (
    input logic clk,
    input logic reset_n,
    // Request to issue new instruction
    input  issue_req_t issue_req_i,
    output issue_rsp_t issue_rsp_o,
    // Complete instruction from alu-memory fu
    input  complete_t  complete_emw_i,
    // Complete instruction from multiply fu
    input  complete_t  complete_mul_i,
    // Commit general (general info)
    output commit_t    commit_o,
    // Commit to register file
    output commit_rf_t commit_rf_o,
    // Commit to store_buffer
    output commit_sb_t commit_sb_o,
    // Peek youngest rs1 value
    input  cam_req_t   cam_req_rs1_i,
    output cam_rsp_t   cam_rsp_rs1_o,
    // Peek youngest rs2 value
    input  cam_req_t   cam_req_rs2_i,
    output cam_rsp_t   cam_rsp_rs2_o
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
        // complete
        logic            complete;
        logic [XLEN-1:0] result;
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
    logic committing_xcpt;
    logic empty, full;
    assign empty = (tail_q == head_q);
    assign full = (tail_q+1 == head_q) | ((&tail_q) & (head_q == '0));

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
        if (entries[head_q].complete & ~empty) begin
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
        if (issue_req_i.valid & ~full) begin
            entries[tail_q].pc       <= issue_req_i.pc;
            entries[tail_q].dbg_ins  <= issue_req_i.dbg_ins;
            entries[tail_q].rd_we    <= issue_req_i.rd_we;
            entries[tail_q].rd_addr  <= issue_req_i.rd_addr;
            entries[tail_q].is_st    <= issue_req_i.is_st;
            entries[tail_q].sbid     <= '0;
            entries[tail_q].complete <= 0;
            entries[tail_q].result   <= '0;
            entries[tail_q].xcpt     <= 0;
        end
        // Complete emw
        if (complete_emw_i.valid) begin
            entries[complete_emw_i.robid].complete <= 1;
            entries[complete_emw_i.robid].result   <= complete_emw_i.result;
            entries[complete_emw_i.robid].xcpt     <= complete_emw_i.xcpt;
            entries[complete_emw_i.robid].sbid     <= complete_emw_i.sbid;
        end
        // Complete mul
        if (complete_mul_i.valid) begin
            entries[complete_mul_i.robid].complete <= 1;
            entries[complete_mul_i.robid].result   <= complete_mul_i.result;
            entries[complete_mul_i.robid].xcpt     <= complete_mul_i.xcpt;
            entries[complete_mul_i.robid].sbid     <= complete_mul_i.sbid;
        end
    end

    // Commit logic
    always_comb begin
        commit_o = '0;
        commit_rf_o = '0;
        commit_sb_o = '0;
        committing_xcpt = 0;
        commit_o.dbg_robid = head_q;
        commit_o.dbg_ins   = entries[head_q].dbg_ins;
        if (entries[head_q].complete & ~empty) begin
            commit_o.valid  = 1;
            commit_o.pc     = entries[head_q].pc;
            commit_o.xcpt   = entries[head_q].xcpt;
            committing_xcpt = entries[head_q].xcpt;
            if (~entries[head_q].xcpt) begin
                if (entries[head_q].is_st) begin
                    commit_sb_o.valid = 1;
                    commit_sb_o.sbid  = entries[head_q].sbid;
                end else begin
                    commit_rf_o.rd_we   = entries[head_q].rd_we;
                    commit_rf_o.rd_addr = entries[head_q].rd_addr;
                    commit_rf_o.rd_data = entries[head_q].result;
                end
            end
        end
    end

    // CAM lookup for younger instructions to use my values
    // RS1
    always_comb begin
        logic   found;
        robid_t found_robid;
        found       = 0;
        found_robid = '0;

        // Default
        cam_rsp_rs1_o = '0;

        if (~empty) begin
            // Go from tail-1 (youngest) til head (oldest) and check
            // RS1
            for (robid_t i = tail_q; i != head_q; --i) begin
                found = (entries[i-1].rd_addr == cam_req_rs1_i.addr) & entries[i-1].complete & ~entries[i-1].xcpt;
                found_robid = i-1;
                if (found) break;
            end
            // Final asssign
            cam_rsp_rs1_o.valid = found;
            cam_rsp_rs1_o.value = entries[found_robid].result;
        end
    end
    // RS2
    always_comb begin
        logic   found;
        robid_t found_robid;
        found       = 0;
        found_robid = '0;

        // Default
        cam_rsp_rs2_o = '0;

        if (~empty) begin
            // Go from tail-1 (youngest) til head (oldest) and check
            // RS1
            for (robid_t i = tail_q; i != head_q; --i) begin
                found = (entries[i-1].rd_addr == cam_req_rs2_i.addr) & entries[i-1].complete & ~entries[i-1].xcpt;
                found_robid = i-1;
                if (found) break;
            end
            // Final asssign
            cam_rsp_rs2_o.valid = found;
            cam_rsp_rs2_o.value = entries[found_robid].result;
        end
    end

endmodule
