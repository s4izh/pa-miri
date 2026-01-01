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
    // Respond with assigned robid
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
    output commit_sb_t commit_sb_o
);
    // Define a type for a reorder buffer entry
    typedef struct packed {
        logic [XLEN-1:0] pc;
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
    //    | rob_id 3 | <- head
    //    | rob_id 4 |
    //    | rob_id 5 |
    //    | rob_id 6 |
    //    | rob_id 7 | <- tail
    //      ........
    robid_t next_tail;
    assign next_tail = tail + 1;
    robid_t tail, head;
    rob_entry_t [N_ENTRIES-1:0] entries;

    // TODO: FSM (?)
    // Control tail
    always @(posedge clk) begin
        if (!reset_n) begin
            tail <= '0;
        end else begin
            if (issue_req_i.valid) begin
                entries[tail].pc       <= issue_req_i.pc;
                entries[tail].rd_we    <= issue_req_i.rd_we;
                entries[tail].rd_addr  <= issue_req_i.rd_addr;
                entries[tail].is_st    <= issue_req_i.is_st;
                entries[tail].sbid     <= '0;
                entries[tail].complete <= 0;
                entries[tail].result   <= '0;
                entries[tail].xcpt     <= 0;
                tail                   <= tail + 1;
            end

            if (complete_emw_i.valid) begin
                // Find the entry completed and mark it as so in the
                // corresponding rob entry
                // TOCHECK: complete_rob_id_i should be between tail and head
                entries[complete_emw_i.robid].complete <= 1;
                entries[complete_emw_i.robid].result   <= complete_emw_i.result;
                entries[complete_emw_i.robid].sbid     <= complete_emw_i.sbid;
            end
        end
    end

    assign issue_rsp_o.robid = tail;
    assign issue_rsp_o.valid = issue_req_i.valid; // & ~full;

    // Control head
    always @(posedge clk) begin
        if (!reset_n) begin
            head <= '0;
        end else begin
            if (entries[head].complete) begin
                head <= head + 1;
            end
        end
    end

    // Output commits
    always_comb begin
        commit_o = '0;
        commit_rf_o = '0;
        commit_sb_o = '0;
        if (entries[head].complete) begin
            commit_o.valid = 1;
            commit_o.xcpt  = entries[head].xcpt;
            commit_o.robid = head;
            if (!entries[head].xcpt) begin
                if (entries[head].is_st) begin
                    commit_sb_o.valid = 1;
                    commit_sb_o.sbid  = entries[head].sbid;
                end else begin
                    commit_rf_o.rd_we   = entries[head].rd_we;
                    commit_rf_o.rd_addr = entries[head].rd_addr;
                    commit_rf_o.rd_data = entries[head].result;
                end
            end
        end
    end

    // TODO: CAM lookup for younger instructions to use my value

endmodule
