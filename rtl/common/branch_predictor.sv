`ifndef _BRANCH_PREDICTOR_M_
`define _BRANCH_PREDICTOR_M_

`include "harness_params.svh"

module branch_predictor #(
    parameter int XLEN = `XLEN,
    parameter int N_ENTRIES = `BP_N_ENTRIES
) (
    input  logic            clk,
    input  logic            reset_n,

    // prediction interface (1f)
    input  logic [XLEN-1:0] req_pc_i,
    output logic            pred_taken_o,
    output logic [XLEN-1:0] pred_target_o,

    // update interface (3e)
    input  logic            upd_valid_i,      // valid branch/jump instruction executed
    input  logic [XLEN-1:0] upd_pc_i,         // pc of that instruction
    input  logic            upd_taken_i,      // outcome
    input  logic [XLEN-1:0] upd_target_i,     // target
    input  logic            upd_is_cond_i     // 1 if conditional branch, 0 if JAL/JALR
);

    localparam int INDEX_BITS = $clog2(N_ENTRIES);
    localparam int TAG_BITS   = XLEN - INDEX_BITS - 2; // -2 for 4-byte alignment

    typedef enum logic [1:0] {
        SNT = 2'b00, // strongly not taken
        WNT = 2'b01, // weakly not taken
        WT  = 2'b10, // weakly taken
        ST  = 2'b11  // strongly taken
    } bht_state_e;

    typedef struct packed {
        logic                  valid;
        logic [TAG_BITS-1:0]   tag;
        logic [XLEN-1:0]       target;
        bht_state_e            cnt;
    } btb_entry_t;

    btb_entry_t entries [N_ENTRIES];

    logic [INDEX_BITS-1:0] pred_idx;
    logic [TAG_BITS-1:0]   pred_tag;

    assign pred_idx = req_pc_i[INDEX_BITS+1:2];
    assign pred_tag = req_pc_i[XLEN-1:INDEX_BITS+2];

    always_comb begin
        pred_taken_o  = 1'b0;
        pred_target_o = req_pc_i + 4; // default to next sequential

        if (entries[pred_idx].valid && entries[pred_idx].tag == pred_tag) begin
            // hit! check counter
            // MSB of counter determines prediction (10, 11 -> Taken)
            if (entries[pred_idx].cnt[1]) begin
                pred_taken_o  = 1'b1;
                pred_target_o = entries[pred_idx].target;
            end
        end
    end

    logic [INDEX_BITS-1:0] upd_idx;
    logic [TAG_BITS-1:0]   upd_tag;
    btb_entry_t            upd_entry;
    bht_state_e            next_cnt;

    assign upd_idx   = upd_pc_i[INDEX_BITS+1:2];
    assign upd_tag   = upd_pc_i[XLEN-1:INDEX_BITS+2];
    assign upd_entry = entries[upd_idx];

    // counter logic
    always_comb begin
        next_cnt = upd_entry.cnt;
        if (upd_taken_i) begin
            if (upd_entry.cnt != ST) next_cnt = bht_state_e'(upd_entry.cnt + 2'b01);
        end else begin
            if (upd_entry.cnt != SNT) next_cnt = bht_state_e'(upd_entry.cnt - 2'b01);
        end
    end

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            for (int i = 0; i < N_ENTRIES; i++) entries[i] <= '0;
        end else if (upd_valid_i) begin
            if (upd_entry.valid && upd_entry.tag == upd_tag) begin
                // update existing entry
                entries[upd_idx].cnt    <= next_cnt;
                // always update target
                entries[upd_idx].target <= upd_target_i; 
            end else if (upd_taken_i) begin
                // allocate new entry ONLY if taken.
                // we don't pollute BTB with never-taken branches.
                entries[upd_idx].valid  <= 1'b1;
                entries[upd_idx].tag    <= upd_tag;
                entries[upd_idx].target <= upd_target_i;
                
                // initialize counter
                // if jump (unconditional), set to strong taken
                // if branch, set to weakly taken
                entries[upd_idx].cnt    <= upd_is_cond_i ? WT : ST;
            end
        end
    end

endmodule

`endif
