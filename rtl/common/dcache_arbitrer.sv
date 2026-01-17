import memory_controller_pkg::*;

module dcache_arbiter #(
    parameter int XLEN = 32
) (
    input  logic clk,
    input  logic reset_n,

    // Priority 1: Pipeline Load (from stage_4m)
    input  logic              ld_req_valid_i,
    input  logic [XLEN-1:0]   ld_req_addr_i,
    input  memop_width_e      ld_req_width_i,
    output logic              ld_req_ready_o,

    // Priority 2: Store Buffer Drain (from store_buffer)
    input  logic              sb_req_valid_i,
    input  logic [XLEN-1:0]   sb_req_addr_i,
    input  logic [XLEN-1:0]   sb_req_data_i,
    input  memop_width_e      sb_req_width_i,
    output logic              sb_req_ready_o,

    // To D-Cache
    input  logic              dc_ready_i,
    output logic              dc_valid_o,
    output logic              dc_we_o,
    output logic [XLEN-1:0]   dc_addr_o,
    output logic [XLEN-1:0]   dc_data_o,
    output memop_width_e      dc_width_o
);

    typedef enum {
        IDLE,
        SERVING_LD,
        SERVING_SB
    } fsm_e;

    fsm_e state, next_state;

    always_ff @(posedge clk) begin
        if (!reset_n) state <= IDLE;
        else          state <= next_state;
    end

    always_comb begin
        // Defaults
        dc_valid_o     = 0;
        dc_we_o        = 0;
        dc_addr_o      = '0;
        dc_data_o      = '0;
        dc_width_o     = MEMOP_WIDTH_32;
        sb_req_ready_o = 0;
        ld_req_ready_o = 0;
        next_state = state;

        case (state)
            IDLE: begin
                if (ld_req_valid_i) begin
                    next_state = SERVING_LD;
                    dc_valid_o = 1;
                    dc_we_o    = 0;
                    dc_addr_o  = ld_req_addr_i;
                    dc_width_o = ld_req_width_i;
                    ld_req_ready_o = dc_ready_i;
                    sb_req_ready_o = 0;
                end else if (sb_req_valid_i) begin
                    next_state = SERVING_SB;
                    dc_valid_o = 1;
                    dc_we_o    = 1;
                    dc_addr_o  = sb_req_addr_i;
                    dc_data_o  = sb_req_data_i;
                    dc_width_o = sb_req_width_i;
                    sb_req_ready_o = dc_ready_i;
                    ld_req_ready_o = 0;
                end
            end
            SERVING_LD: begin
                dc_valid_o = 1;
                dc_we_o    = 0;
                dc_addr_o  = ld_req_addr_i;
                dc_width_o = ld_req_width_i;
                ld_req_ready_o = dc_ready_i;
                sb_req_ready_o = 0;
                if (dc_ready_i) next_state = IDLE;
            end
            SERVING_SB: begin
                dc_valid_o = 1;
                dc_we_o    = 1;
                dc_addr_o  = sb_req_addr_i;
                dc_data_o  = sb_req_data_i;
                dc_width_o = sb_req_width_i;
                sb_req_ready_o = dc_ready_i;
                ld_req_ready_o = 0;
                if (dc_ready_i) next_state = IDLE;
            end
        endcase
    end

endmodule
