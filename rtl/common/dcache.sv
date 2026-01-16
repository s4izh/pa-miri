module dcache #(
    parameter int XLEN = 32,
    parameter int WAYS = 4,

    // Non-modifiable (slides specify them)
    parameter int SETS = 4,
    parameter int BITS_CACHELINE = 128
) (
    input logic clk,
    input logic reset_n,

    // Interface with core (d for data)
    // Request
    input  logic                      dreq_valid_i,
    output logic                      dreq_ready_o,
    input  logic [XLEN-1:0]           dreq_addr_i,
    input  logic                      dreq_we_i,
    input  logic [BITS_CACHELINE-1:0] dreq_data_i,
    input  logic [BITS_CACHELINE-1:0] dreq_data_mask_i,
    // Response
    output logic [BITS_CACHELINE-1:0] drsp_data_o,
    // Interface with memory (f for fill)
    // Request to memory
    output logic                      freq_valid_o,
    output logic                      freq_we_o,
    output logic [BITS_CACHELINE-1:0] freq_data_o,
    output logic [XLEN-1:0]           freq_addr_o,
    // Response from memory
    input  logic                      frsp_valid_i,
    input  logic [BITS_CACHELINE-1:0] frsp_data_i
);
    localparam BITS_OFFSET_ELEMENT = $clog2(BITS_CACHELINE/XLEN); // Element offset size
    localparam BITS_OFFSET  = $clog2(BITS_CACHELINE/8); // Byte offset size
    localparam BITS_SET     = $clog2(SETS);
    localparam BITS_TAG     = XLEN - BITS_SET - BITS_OFFSET;

    logic [BITS_SET-1:0] dreq_addr_set_id;
    logic [BITS_TAG-1:0] dreq_addr_tag;
    assign dreq_addr_set_id = dreq_addr_i[BITS_SET+BITS_OFFSET-1:BITS_OFFSET];
    assign dreq_addr_tag    = dreq_addr_i[XLEN-1:BITS_SET+BITS_OFFSET];

    typedef struct {
        logic                      valid;
        logic                      dirty;
        logic [BITS_TAG-1:0]       tag;
        logic [BITS_CACHELINE-1:0] data;
    } way_t;

    typedef struct {
        logic [$clog2(WAYS)-1:0] replace_idx;
        way_t                    ways[WAYS];
    } set_t;

    typedef enum {
        FSM_IDLE,
        FSM_READ,
        FSM_EVICT
    } fsm_e;

    fsm_e fsm_state;
    set_t sets[SETS];
    logic [WAYS-1:0] hits;

    // Replacement index of the set of the current request address
    logic [$clog2(WAYS)-1:0] current_set_replace_idx;
    assign current_set_replace_idx = sets[dreq_addr_set_id].replace_idx;

    // Valid/dirty of the line to substitute
    logic current_valid_and_dirty;
    assign current_valid_and_dirty =
        sets[dreq_addr_set_id].ways[current_set_replace_idx].valid &
        sets[dreq_addr_set_id].ways[current_set_replace_idx].dirty;

    // FSM transitions
    logic idle_to_read, idle_to_evict, evict_to_read, read_to_idle;
    // Idle -> Read - We want to read/write to the cache: the set does NOT
    // have the line we want and the way to replace is not valid nor dirty.
    assign idle_to_read  = dreq_valid_i & ~(|hits) & ~current_valid_and_dirty;
    // Idle -> Evict - We want to read/write to the cache: the set does
    // have the line we want and the way to replace is valid and dirty
    assign idle_to_evict = dreq_valid_i & ~(|hits) & current_valid_and_dirty;
    // Evict -> Read - Only transition to read once the dirty cache line has
    // been fully written to the next memory level.
    assign evict_to_read = frsp_valid_i;
    // Read -> Idle - Transition only after our read request has finished
    assign read_to_idle = frsp_valid_i;

    // FSM
    always @(posedge clk) begin
        logic            freq_valid;
        logic            freq_we;
        logic [BITS_CACHELINE-1:0] freq_data;
        logic [XLEN-1:0] freq_addr;

        freq_valid = freq_valid_o;
        freq_we    = freq_we_o;
        freq_addr  = freq_addr_o;
        freq_data  = freq_data_o;

        if (!reset_n) begin
            fsm_state <= FSM_IDLE;
            for (int l = 0; l < SETS; ++l) begin
                for (int w = 0; w < WAYS; ++w) begin
                    sets[l].ways[w].valid <= 0;
                    sets[l].ways[w].dirty <= 0;
                    sets[l].replace_idx   <= '0;
                end
            end
            freq_valid = 0;
            freq_addr  = '0;
        end else begin
            case (fsm_state)
                FSM_IDLE: begin
                    if (idle_to_read) begin
                        fsm_state <= FSM_READ;
                        freq_valid = 1;
                        freq_we    = 0;
                        freq_addr  = dreq_addr_i;
                    end else if (idle_to_evict) begin
                        fsm_state <= FSM_EVICT;
                        freq_valid = 1;
                        freq_we    = 1;
                        freq_addr  = {sets[dreq_addr_set_id].ways[current_set_replace_idx].tag, dreq_addr_i[BITS_SET+BITS_OFFSET-1:0]};
                        freq_data  = sets[dreq_addr_set_id].ways[current_set_replace_idx].data;
                    end else begin
                        if (dreq_we_i) begin
                            sets[dreq_addr_set_id].ways[$clog2(hits)].dirty <= 1;
                            sets[dreq_addr_set_id].ways[$clog2(hits)].data  <=
                                sets[dreq_addr_set_id].ways[$clog2(hits)].data & ~dreq_data_mask_i | dreq_data_i & dreq_data_mask_i;
                        end
                        // no change
                        freq_valid = 0;
                    end
                end
                FSM_READ: begin
                    if (read_to_idle) begin
                        // change
                        fsm_state <= FSM_IDLE;
                        freq_valid = 0;
                        sets[dreq_addr_set_id].replace_idx                             <= current_set_replace_idx + 1;
                        sets[dreq_addr_set_id].ways[current_set_replace_idx].valid         <= 1;
                        sets[dreq_addr_set_id].ways[current_set_replace_idx].tag           <= dreq_addr_tag;
                            sets[dreq_addr_set_id].ways[current_set_replace_idx].dirty <= dreq_we_i;
                        if (dreq_we_i) begin
                            sets[dreq_addr_set_id].ways[current_set_replace_idx].data  <= frsp_data_i & ~dreq_data_mask_i |
                                                                                  dreq_data_i & dreq_data_mask_i;
                        end else begin
                            sets[dreq_addr_set_id].ways[current_set_replace_idx].data  <= frsp_data_i;
                        end
                    end
                    // no change
                end
                FSM_EVICT: begin
                    if (evict_to_read) begin
                        sets[dreq_addr_set_id].ways[current_set_replace_idx].dirty <= 0;
                        fsm_state <= FSM_READ;
                        freq_valid = 1;
                        freq_we    = 0;
                        freq_addr  = dreq_addr_i;
                    end
                end
            endcase
        end

        freq_valid_o <= freq_valid;
        freq_we_o    <= freq_we;
        freq_addr_o  <= freq_addr;
        freq_data_o  <= freq_data;
    end

    // Ready
    assign dreq_ready_o =
          ((fsm_state == FSM_IDLE) & ~(idle_to_read | idle_to_evict))
        | ((fsm_state == FSM_READ) & read_to_idle);

    // Hit detection
    always_comb begin
        `define way(i) sets[dreq_addr_set_id].ways[(i)]
        for (int w = 0; w < WAYS; ++w) begin
            hits[w] = (`way(w).valid & (`way(w).tag == dreq_addr_tag));
        end
        `undef way
    end

    // Data to core with bypass
    logic drsp_bypass_valid;
    assign drsp_bypass_valid = (fsm_state == FSM_READ) & read_to_idle;
    always_comb begin
        if (drsp_bypass_valid) begin
            drsp_data_o = frsp_data_i;
        end else begin
            drsp_data_o = sets[dreq_addr_set_id].ways[$clog2(hits)].data;
        end
    end

endmodule
