import memory_controller_pkg::*;

module dcache_arbiter #(
    parameter int XLEN = 32
) (
    // Priority 1: Pipeline Load (from stage_4m)
    input  logic              ld_req_valid_i,
    input  logic [XLEN-1:0]   ld_req_addr_i,
    input  memop_width_e      ld_req_width_i,
    
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

    always_comb begin
        // Defaults
        dc_valid_o     = 0;
        dc_we_o        = 0;
        dc_addr_o      = '0;
        dc_data_o      = '0;
        dc_width_o     = MEMOP_WIDTH_32;
        sb_req_ready_o = 0;

        if (ld_req_valid_i) begin
            // Load takes priority
            dc_valid_o = 1;
            dc_we_o    = 0; // Loads are reads
            dc_addr_o  = ld_req_addr_i;
            dc_width_o = ld_req_width_i;
            // Store buffer must wait
            sb_req_ready_o = 0;
        end else if (sb_req_valid_i) begin
            // Store buffer drains if load is idle
            dc_valid_o = 1;
            dc_we_o    = 1; // Stores are writes
            dc_addr_o  = sb_req_addr_i;
            dc_data_o  = sb_req_data_i;
            dc_width_o = sb_req_width_i;
            // Pass ready signal back to SB
            sb_req_ready_o = dc_ready_i;
        end

    end

endmodule
