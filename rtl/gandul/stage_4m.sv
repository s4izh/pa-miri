import rv_datapath_pkg::*;
import store_buffer_pkg::*;
import rob_pkg::*; 

`include "harness_params.svh"

module stage_4m #(
    parameter int XLEN = 32,
    parameter int WAYS = 4,
    parameter int SETS = 4,
    parameter int BITS_CACHELINE = 128
) (
    input logic clk,
    input logic reset_n,
    
    // pipeline input/output
    input  signals_execute_t _i,
    output signals_memory_t  _o,
    
    // trap/control
    input  logic         stall_i,
    input  logic         noop_i,
    output logic         waiting_for_memory_o,
    input  logic         flush_i, 
    
    // store buffer allocation (from Stage 2D)
    input  logic         sb_alloc_en_i,
    output sbid_t        sb_alloc_idx_o,
    output logic         sb_full_o,
    
    // store buffer commit (interface with ROB)
    input  logic         rob_commit_sb_valid_i,
    input  sbid_t        rob_commit_sb_idx_i,

    // memory refill interface
    output dmem_if_out_t dmem_o,
    input  dmem_if_in_t  dmem_i
);
    `define PROPAGATE(signal) assign _o.signal = _i.signal

    // Internal Signals
    logic [XLEN-1:0] data_sign_extended;
    logic [XLEN-1:0] load_final_data;
    
    logic pipe_load_valid;
    logic pipe_store_valid;
    logic addr_misaligned;

    // store buffer signals
    logic            sb_ce;
    sbid_t           sb_idx;
    logic [XLEN-1:0] sb_addr, sb_data;
    memop_width_e    sb_width;
    logic            sb_hit, sb_stall;
    logic [XLEN-1:0] sb_fwd_data;
    logic            sb_empty; 
    
    // drain signals (SB -> Arbiter)
    logic            sb_dreq_valid, sb_dreq_ready;
    logic [XLEN-1:0] sb_dreq_addr, sb_dreq_data;
    logic            sb_dreq_we;
    memop_width_e    sb_dreq_width;

    // arbiter -> cache signals (Internal)
    logic             dc_req_valid, dc_req_ready;
    logic [XLEN-1:0]  dc_req_addr, dc_req_data;
    logic             dc_req_we;
    memop_width_e     dc_req_width;

    // cache -> stage signals (Internal)
    logic [XLEN-1:0]  dc_rsp_data;
    logic             dc_rsp_xcpt;

    assign pipe_load_valid  = _i.valid & _i.is_ld;
    assign pipe_store_valid = _i.valid & _i.is_st;

    // Check alignment BEFORE accessing SB or D$
    always_comb begin
        addr_misaligned = 1'b0;
        if (_i.valid && (_i.is_ld || _i.is_st)) begin
            case (_i.memop_width)
                MEMOP_WIDTH_16: if (_i.alu_result[0])           addr_misaligned = 1'b1;
                MEMOP_WIDTH_32: if (_i.alu_result[1:0] != 2'b0) addr_misaligned = 1'b1;
                default: ;
            endcase
        end
    end

    // Execution Update: Only write to SB if valid, not stalled, AND ALIGNED.
    assign sb_ce    = pipe_store_valid & ~stall_i & ~addr_misaligned;
    assign sb_idx   = _i.sbid;
    assign sb_addr  = _i.alu_result;
    assign sb_data  = _i.rs2_data;
    assign sb_width = _i.memop_width;

    store_buffer sb_inst (
        .clk(clk),
        .reset_n(reset_n),

        // Allocation (From Stage 2D)
        .alloc_en_i(sb_alloc_en_i),
        .alloc_idx_o(sb_alloc_idx_o),
        .sb_full_o(sb_full_o),

        // Execute (Data Update from Pipeline)
        .creq_en_i(sb_ce),
        .creq_idx_i(sb_idx),
        .creq_addr_i(sb_addr),
        .creq_data_i(sb_data),
        .creq_width_i(sb_width),

        // Commit (From ROB)
        .commit_en_i(rob_commit_sb_valid_i),
        .commit_idx_i(rob_commit_sb_idx_i),

        // Control
        .fence_i(_i.is_fence & _i.valid),
        .flush_i(flush_i),
        .sb_empty_o(sb_empty),

        // Forwarding (Hazard Check for Loads)
        .ld_addr_i(_i.alu_result),
        .ld_width_i(_i.memop_width),
        .ld_age_tag_i(_i.sbid), 
        .ld_hit_o(sb_hit),
        .ld_stall_o(sb_stall),
        .ld_data_o(sb_fwd_data),

        // DCache Drain Interface
        .dreq_valid_o(sb_dreq_valid),
        .dreq_ready_i(sb_dreq_ready),
        .dreq_addr_o(sb_dreq_addr),
        .dreq_data_o(sb_dreq_data),
        .dreq_we_o(sb_dreq_we),
        .dreq_width_o(sb_dreq_width)
    );

    // Arbitration (Pipeline Load vs SB Drain)
    logic ld_req_ready;
    logic ld_req_valid;

    assign ld_req_valid = pipe_load_valid & ~sb_stall & ~sb_hit & ~addr_misaligned;

    dcache_arbiter #(
        .XLEN(XLEN)
    ) internal_arbiter (
        .clk,
        .reset_n,
        // Priority 1: Pipeline Load
        .ld_req_valid_i (ld_req_valid),
        .ld_req_addr_i  (_i.alu_result),
        .ld_req_width_i (_i.memop_width),
        .ld_req_ready_o (ld_req_ready),

        // Priority 2: Store Buffer Drain
        .sb_req_valid_i (sb_dreq_valid),
        .sb_req_addr_i  (sb_dreq_addr),
        .sb_req_data_i  (sb_dreq_data),
        .sb_req_width_i (sb_dreq_width),
        .sb_req_ready_o (sb_dreq_ready),

        // To Internal D-Cache
        .dc_ready_i     (dc_req_ready),
        .dc_valid_o     (dc_req_valid),
        .dc_we_o        (dc_req_we),
        .dc_addr_o      (dc_req_addr),
        .dc_data_o      (dc_req_data),
        .dc_width_o     (dc_req_width)
    );

    dcache_wrapper #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) dcache_inst (
        .clk(clk),
        .reset_n(reset_n),

        // Core side (From Arbiter)
        .dreq_valid_i(dc_req_valid),
        .dreq_ready_o(dc_req_ready),
        .dreq_addr_i(dc_req_addr),
        .dreq_data_i(dc_req_data),
        .dreq_we_i(dc_req_we),
        .dreq_width_i(dc_req_width),

        .drsp_data_o(dc_rsp_data),
        .drsp_xcpt_o(dc_rsp_xcpt),

        // Memory side (Refill -> Module Ports)
        .freq_valid_o(dmem_o.valid),
        .freq_we_o(dmem_o.we),
        .freq_data_o(dmem_o.data),
        .freq_addr_o(dmem_o.addr),

        .frsp_valid_i(dmem_i.valid),
        .frsp_data_i(dmem_i.data)
    );

    assign load_final_data = (sb_hit) ? sb_fwd_data : dc_rsp_data;

    sign_extender #(
        .XLEN(XLEN)
    ) sign_extender_inst (
        .data_i        (load_final_data),
        .width_i       (_i.memop_width),
        .data_signed_o (data_sign_extended)
    );

    // Stall logic
    // - SB Hazard: We need to wait for store data to arrive in buffer
    // - D$ Busy: We requested a load but D$ is handling refill or drain
    // - SB fence: a fence instruction was requested, wait till all stores are sent to cache
    assign waiting_for_memory_o = (pipe_load_valid && !addr_misaligned && sb_stall) || 
                                  (ld_req_valid && !ld_req_ready) ||
                                  (_i.valid && _i.is_fence && !sb_empty);

    // Pipeline Register Outputs
    always_comb begin
        if (noop_i | stall_i) begin
            _o.valid  = 0;
            _o.is_wb  = 0;
            _o.ins    = 32'h00000033;
            _o.xcpt   = 0;
        end else begin
            _o.valid  = _i.valid;
            _o.is_wb  = _i.is_wb;
            _o.ins    = _i.ins;
            
            if (_i.xcpt) begin
                // previous exception
                _o.xcpt = _i.xcpt;
            end else if (addr_misaligned) begin
                // alignment exception
                _o.xcpt = 1'b1;
            end else begin
                // Flag D-Cache exception only if we actually used the D-Cache data
                // (not a store buffer hit)
                _o.xcpt = dc_rsp_xcpt & pipe_load_valid & ~sb_hit;
            end
        end
    end

    `PROPAGATE(pc);
    `PROPAGATE(wb_sel);
    `PROPAGATE(rd_addr);
    `PROPAGATE(alu_result);
    `PROPAGATE(robid);
    `PROPAGATE(sbid);

    // final result selection (Sign Extension)
    always_comb begin
        if (_i.ld_unsigned == 1)
            _o.mem_result = load_final_data;
        else
            _o.mem_result = data_sign_extended;
    end

endmodule
