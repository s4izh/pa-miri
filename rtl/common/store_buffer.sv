`ifndef _STORE_BUFFER_M_
`define _STORE_BUFFER_M_

import memory_controller_pkg::*;

module store_buffer #(
    parameter int XLEN = 32,
    parameter int DEPTH = 8,
    parameter int DRAIN_THRESHOLD = 6,
    localparam int SB_IDX_W = $clog2(DEPTH)
) (
    input logic clk,
    input logic reset_n,

    // --- dispatch (allocation) ---
    input  logic                alloc_en_i,
    output logic [SB_IDX_W-1:0] alloc_idx_o,
    output logic                sb_full_o,

    // --- execute (data update from store unit) ---
    input  logic                creq_en_i,
    input  logic [SB_IDX_W-1:0] creq_idx_i,
    input  logic [XLEN-1:0]     creq_addr_i,
    input  logic [XLEN-1:0]     creq_data_i,
    input  memop_width_e        creq_width_i,

    // --- commit (from ROB) ---
    input  logic                commit_en_i,
    input  logic [SB_IDX_W-1:0] commit_idx_i,

    // --- control ---
    input  logic                fence_i,
    output logic                sb_empty_o,

    // --- forwarding / hazard interface ---
    input  logic [XLEN-1:0]     ld_addr_i,
    input  memop_width_e        ld_width_i,
    input  logic [SB_IDX_W-1:0] ld_age_tag_i,
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

    typedef struct packed {
        logic [XLEN-1:0] addr;
        logic [XLEN-1:0] data;
        memop_width_e    width;
        logic            valid;     
        logic            committed; 
        logic            allocated; 
    } sb_entry_t;

    sb_entry_t buffer [DEPTH];
    logic [SB_IDX_W-1:0] head, tail;
    logic [SB_IDX_W:0]   count;

    typedef enum logic { ST_IDLE, ST_DRAIN } state_e;
    state_e state;

    // logic to decide when we "really need" to drain
    logic drain_needed;
    // FENCE forces a drain regardless of count threshold
    assign drain_needed = (count >= (SB_IDX_W+1)'(DRAIN_THRESHOLD)) || ld_stall_o || fence_i;

    // FIFO MANAGEMENT
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            tail  <= '0;
            count <= '0;
            for (int i=0; i<DEPTH; i++) buffer[i] <= '0;
        end else begin
            // allocation
            if (alloc_en_i && !sb_full_o) begin
                buffer[tail].allocated <= 1'b1;
                buffer[tail].valid     <= 1'b0;
                buffer[tail].committed <= 1'b0;
                tail <= tail + 1'b1;
            end

            // execution (EU provides data)
            if (creq_en_i) begin
                buffer[creq_idx_i].addr  <= creq_addr_i;
                buffer[creq_idx_i].data  <= creq_data_i;
                buffer[creq_idx_i].width <= creq_width_i;
                buffer[creq_idx_i].valid <= 1'b1;
            end

            // commit (ROB retires the store)
            if (commit_en_i) begin
                buffer[commit_idx_i].committed <= 1'b1;
            end

            // deallocation (FSM finished writing to Cache)
            if (dreq_valid_o && dreq_ready_i) begin
                buffer[head].allocated <= 1'b0;
            end

            // entry counter
            case ({ (alloc_en_i && !sb_full_o), (dreq_valid_o && dreq_ready_i) })
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: ; 
            endcase
        end
    end

    // DRAIN FSM
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            state <= ST_IDLE;
            head  <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    if (buffer[head].allocated && buffer[head].valid && 
                        buffer[head].committed && drain_needed) begin
                        state <= ST_DRAIN;
                    end
                end

                ST_DRAIN: begin
                    if (dreq_ready_i) begin
                        // Re-evaluate if we need to stay in DRAIN mode
                        // We check the "next" head (which is head + 1)
                        logic [SB_IDX_W-1:0] next_head;
                        next_head = head + 1'b1;
                        if (!(buffer[next_head].allocated && 
                              buffer[next_head].committed && 
                              drain_needed)) begin
                            state <= ST_IDLE;
                        end
                        head <= next_head;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

    assign dreq_valid_o = (state == ST_DRAIN);
    assign dreq_addr_o  = buffer[head].addr;
    assign dreq_data_o  = buffer[head].data;
    assign dreq_width_o = buffer[head].width;
    assign dreq_we_o    = 1'b1;

    assign sb_full_o    = (count == (SB_IDX_W+1)'(DEPTH));
    assign sb_empty_o   = (count == '0);

    assign alloc_idx_o  = tail;

    // combinational forwarding logic
    always_comb begin
        logic [3:0] ld_be;
        logic [3:0] st_be;
        logic [SB_IDX_W-1:0] curr_idx;
        logic is_older;

        case (ld_width_i)
            MEMOP_WIDTH_8:  ld_be = 4'b0001 << ld_addr_i[1:0];
            MEMOP_WIDTH_16: ld_be = 4'b0011 << ld_addr_i[1:0];
            MEMOP_WIDTH_32: ld_be = 4'b1111;
            default:        ld_be = 4'b0000;
        endcase

        ld_hit_o   = 1'b0;
        ld_stall_o = 1'b0;
        ld_data_o  = '0;

        for (int i = 1; i <= DEPTH; i++) begin
            curr_idx = ld_age_tag_i - i[SB_IDX_W-1:0];
            
            // age check
            if (head <= ld_age_tag_i) is_older = (curr_idx >= head && curr_idx < ld_age_tag_i);
            else                      is_older = (curr_idx >= head || curr_idx < ld_age_tag_i);

            if (is_older && buffer[curr_idx].allocated) begin
                // inline BE generation for the store entry
                case (buffer[curr_idx].width)
                    MEMOP_WIDTH_8:  st_be = 4'b0001 << buffer[curr_idx].addr[1:0];
                    MEMOP_WIDTH_16: st_be = 4'b0011 << buffer[curr_idx].addr[1:0];
                    MEMOP_WIDTH_32: st_be = 4'b1111;
                    default:        st_be = 4'b0000;
                endcase

                if (buffer[curr_idx].addr[XLEN-1:2] == ld_addr_i[XLEN-1:2]) begin
                    if ((st_be & ld_be) != 4'b0000) begin
                        // exact match (same address and same byte mask)
                        if (buffer[curr_idx].addr == ld_addr_i && st_be == ld_be) begin
                            if (buffer[curr_idx].valid) begin
                                ld_hit_o  = 1'b1;
                                ld_data_o = buffer[curr_idx].data;
                            end else begin
                                ld_stall_o = 1'b1; 
                            end
                            break; 
                        end else begin
                            ld_stall_o = 1'b1;
                            break; 
                        end
                    end
                end
            end
        end
    end

endmodule

`endif
