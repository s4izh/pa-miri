`ifndef _STORE_BUFFER_M_
`define _STORE_BUFFER_M_

`include "harness_params.svh"

import store_buffer_pkg::*;
import memory_controller_pkg::*;

module store_buffer #(
    parameter int XLEN = `XLEN,
    parameter int DEPTH = `SB_N_ENTRIES,
    parameter int DRAIN_THRESHOLD = `SB_DRAIN_THRESHOLD
) (
    input logic clk,
    input logic reset_n,

    // --- dispatch (allocation) ---
    input  logic                alloc_en_i,
    output sbid_t               alloc_idx_o,
    output logic                sb_full_o,

    // --- execute (data update from store unit) ---
    input  logic                creq_en_i,
    input  sbid_t               creq_idx_i,
    input  logic [XLEN-1:0]     creq_addr_i,
    input  logic [XLEN-1:0]     creq_data_i,
    input  memop_width_e        creq_width_i,

    // --- commit (from ROB) ---
    input  logic                commit_en_i,
    input  sbid_t               commit_idx_i,

    // --- control ---
    input  logic                fence_i,
    input  logic                flush_i,
    output logic                sb_empty_o,

    // --- forwarding / hazard interface ---
    input  logic [XLEN-1:0]     ld_addr_i,
    input  memop_width_e        ld_width_i,
    input  sbid_t               ld_age_tag_i,
    output logic                ld_hit_o,     
    output logic                ld_stall_o,   
    output logic [XLEN-1:0]     ld_data_o,

    // --- dcache interface ---
    output logic              dreq_valid_o,
    input  logic              dreq_ready_i, 
    output logic [XLEN-1:0]   dreq_addr_o,
    output logic [XLEN-1:0]   dreq_data_o,
    output logic              dreq_we_o,      
    output memop_width_e      dreq_width_o
);
    localparam int SB_IDX_W = $clog2(DEPTH);

    typedef struct packed {
        logic [XLEN-1:0] addr;
        logic [XLEN-1:0] data;
        memop_width_e    width;
        logic            valid;     
        logic            committed; 
        logic            allocated; 
    } sb_entry_t;

    sb_entry_t buffer [DEPTH];
    // head_ptr: oldest committed store, waiting for dcache
    // tail_ptr: next speculative slot to allocate
    // commit_ptr: next slot expected to be committed by ROB
    sbid_t head_ptr, tail_ptr, commit_ptr;
    logic [SB_IDX_W:0]   count;

    typedef enum logic { ST_IDLE, ST_DRAIN } state_e;
    state_e state;

    assign sb_full_o    = (count == (SB_IDX_W+1)'(DEPTH));
    assign sb_empty_o   = (count == '0);
    assign alloc_idx_o  = tail_ptr;

    logic drain_needed;
    assign drain_needed = (count >= (SB_IDX_W+1)'(DRAIN_THRESHOLD)) || ld_stall_o || fence_i;

    // dcache interface
    assign dreq_valid_o = (state == ST_DRAIN);
    assign dreq_addr_o  = buffer[head_ptr].addr;
    assign dreq_data_o  = buffer[head_ptr].data;
    assign dreq_width_o = buffer[head_ptr].width;
    assign dreq_we_o    = 1'b1;

    always_ff @(posedge clk) begin

        sbid_t next_head;
        next_head = head_ptr + 1'b1;

        if (!reset_n) begin
            tail_ptr       <= '0;
            head_ptr       <= '0;
            commit_ptr     <= '0;
            count          <= '0;
            state          <= ST_IDLE;
            for (int i = 0; i < DEPTH; i++) buffer[i] <= '0;
        end else if (flush_i) begin
            // reset allocation tail_ptr to the last committed instruction's next slot
            tail_ptr <= commit_ptr;
            
            // clear allocated bits for all speculative entries
            for (int i = 0; i < DEPTH; i++) begin
                if (!buffer[i].committed) begin
                    buffer[i].allocated <= 1'b0;
                    buffer[i].valid     <= 1'b0;
                end
            end

            if (commit_ptr >= head_ptr) begin
                count <= (SB_IDX_W+1)'(32'(commit_ptr) - 32'(head_ptr));
            end else begin
                // distance = DEPTH - (head_ptr - commit_ptr)
                count <= (SB_IDX_W+1)'(32'(DEPTH) - (32'(head_ptr) - 32'(commit_ptr)));
            end

            // force FSM back to IDLE if it was trying to drain a speculative entry
            // buffer[head_ptr].committed check in IDLE usually handles this
            state <= ST_IDLE;

        end else begin
            // allocation
            if (alloc_en_i && !sb_full_o) begin
                buffer[tail_ptr].allocated <= 1'b1;
                buffer[tail_ptr].valid     <= 1'b0;
                buffer[tail_ptr].committed <= 1'b0;
                tail_ptr <= tail_ptr + 1'b1;
            end

            // execution, data coming from alumem
            if (creq_en_i) begin
                buffer[creq_idx_i].addr  <= creq_addr_i;
                buffer[creq_idx_i].data  <= creq_data_i;
                buffer[creq_idx_i].width <= creq_width_i;
                buffer[creq_idx_i].valid <= 1'b1;
            end

            // store is commited
            if (commit_en_i) begin
                buffer[commit_idx_i].committed <= 1'b1;
                commit_ptr <= commit_ptr + 1'b1;
            end

            // deallocation & draining
            case (state)
                ST_IDLE: begin
                    if (buffer[head_ptr].allocated && buffer[head_ptr].valid && 
                        buffer[head_ptr].committed && drain_needed) begin
                        state <= ST_DRAIN;
                    end
                end

                ST_DRAIN: begin
                    if (dreq_ready_i) begin
                        buffer[head_ptr].allocated <= 1'b0;
                        buffer[head_ptr].valid     <= 1'b0;
                        buffer[head_ptr].committed <= 1'b0;
                        
                        head_ptr <= next_head;

                        // check if next entry is also ready to drain
                        if (!(buffer[next_head].allocated && 
                              buffer[next_head].valid && 
                              buffer[next_head].committed && 
                              drain_needed)) begin
                            state <= ST_IDLE;
                        end
                    end
                end
            endcase

            // count
            // note: on flush_i we recalculate, so this only handles normal cycles
            case ({ (alloc_en_i && !sb_full_o), (dreq_valid_o && dreq_ready_i) })
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: ; 
            endcase
        end
    end

    // forwarding
    always_comb begin
        logic [3:0] ld_be;
        logic [3:0] st_be;
        sbid_t curr_idx;
        logic is_older;
        logic [4:0]      shift_amt;
        logic [1:0]      offset_diff;
        logic [XLEN-1:0] raw_shifted_data;

        case (ld_width_i)
            MEMOP_WIDTH_8:  ld_be = 4'b0001 << ld_addr_i[1:0];
            MEMOP_WIDTH_16: ld_be = 4'b0011 << ld_addr_i[1:0];
            MEMOP_WIDTH_32: ld_be = 4'b1111;
            default:        ld_be = 4'b0000;
        endcase

        ld_hit_o     = 1'b0;
        ld_stall_o   = 1'b0;
        ld_data_o    = '0;
        shift_amt    = '0;
        offset_diff  = '0;

        for (int i = 1; i <= DEPTH; i++) begin
            curr_idx = ld_age_tag_i - i[SB_IDX_W-1:0];
            
            // age check to find youngest-older store
            if (head_ptr <= ld_age_tag_i) is_older = (curr_idx >= head_ptr && curr_idx < ld_age_tag_i);
            else                          is_older = (curr_idx >= head_ptr || curr_idx < ld_age_tag_i);

            if (is_older && buffer[curr_idx].allocated && buffer[curr_idx].valid) begin
                case (buffer[curr_idx].width)
                    MEMOP_WIDTH_8:  st_be = 4'b0001 << buffer[curr_idx].addr[1:0];
                    MEMOP_WIDTH_16: st_be = 4'b0011 << buffer[curr_idx].addr[1:0];
                    MEMOP_WIDTH_32: st_be = 4'b1111;
                    default:        st_be = 4'b0000;
                endcase

                if (buffer[curr_idx].addr[XLEN-1:2] == ld_addr_i[XLEN-1:2]) begin
                    if ((st_be & ld_be) != 4'b0000) begin
                        if ((st_be & ld_be) == ld_be) begin
                            ld_hit_o  = 1'b1;

                            offset_diff = ld_addr_i[1:0] - buffer[curr_idx].addr[1:0];
                            shift_amt = {offset_diff, 3'b000};
                            raw_shifted_data = buffer[curr_idx].data >> shift_amt;

                            case (ld_width_i)
                                MEMOP_WIDTH_8:  ld_data_o = { {(XLEN-8){1'b0}}, raw_shifted_data[7:0] };
                                MEMOP_WIDTH_16: ld_data_o = { {(XLEN-16){1'b0}}, raw_shifted_data[15:0] };
                                default:        ld_data_o = raw_shifted_data;
                            endcase
                            break; 
                        end else begin
                            ld_stall_o = 1'b1; // partial overlap, wait till there isn't one
                            break; 
                        end
                    end else begin
                        // keep checking for an overlap
                    end
                end
            end
        end
    end

endmodule

`endif
