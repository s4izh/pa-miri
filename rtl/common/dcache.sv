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
    output logic                      drsp_hit_o,
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
    assign dreq_addr_tag     = dreq_addr_i[XLEN-1:BITS_SET+BITS_OFFSET];

    typedef struct {
        logic                       valid;
        logic [BITS_TAG-1:0]        tag;
        logic [BITS_CACHELINE-1:0]  data;
    } way_t;

    typedef struct {
        logic [$clog2(WAYS)-1:0] replace_idx;
        way_t                    ways[WAYS];
    } set_t;

    typedef enum {
        FSM_IDLE,
        FSM_WAIT_READ,
        FSM_WAIT_READ4WRITE,
        FSM_WAIT_WRITE
    } fsm_e;

    fsm_e fsm_state;
    set_t sets[SETS];
    logic [WAYS-1:0] hits;

    // FSM
    always @(posedge clk) begin
        logic            dreq_ready;
        logic            freq_valid;
        logic            freq_we;
        logic [BITS_CACHELINE-1:0] freq_data;
        logic [XLEN-1:0] freq_addr;

        dreq_ready = dreq_ready_o;
        freq_valid = freq_valid_o;
        freq_we    = freq_we_o;
        freq_addr  = freq_addr_o;
        freq_data  = freq_data_o;

        if (!reset_n) begin
            fsm_state <= FSM_IDLE;
            for (int l = 0; l < SETS; ++l) begin
                for (int w = 0; w < WAYS; ++w) begin
                    sets[l].ways[w].valid <= 0;
                    sets[l].replace_idx   <= '0;
                end
            end
            freq_valid = 0;
            freq_addr  = '0;
            dreq_ready = 0;
        end else begin
            case (fsm_state)
                FSM_IDLE: begin
                    if (dreq_valid_i & ~(|hits)) begin
                        if (dreq_we_i) begin
                            fsm_state <= FSM_WAIT_READ4WRITE;
                        end else begin
                            fsm_state <= FSM_WAIT_READ;
                        end
                        freq_valid = 1;
                        freq_we    = 0;
                        freq_addr  = dreq_addr_i;
                        dreq_ready = 0;
                    end else if (dreq_valid_i & dreq_we_i & (|hits)) begin
                        fsm_state <= FSM_WAIT_WRITE;
                    end else begin
                        // no change
                        freq_valid = 0;
                        dreq_ready = 1;
                    end
                end
                FSM_WAIT_READ: begin
                    if (frsp_valid_i) begin
                        logic [$clog2(WAYS)-1:0] replace_idx_tmp;
                        // change
                        fsm_state <= FSM_IDLE;
                        freq_valid = 0;
                        replace_idx_tmp = sets[dreq_addr_set_id].replace_idx;
                        sets[dreq_addr_set_id].replace_idx                 <= replace_idx_tmp + 1;
                        sets[dreq_addr_set_id].ways[replace_idx_tmp].valid <= 1;
                        sets[dreq_addr_set_id].ways[replace_idx_tmp].tag   <= dreq_addr_tag;
                        sets[dreq_addr_set_id].ways[replace_idx_tmp].data  <= frsp_data_i;
                        dreq_ready = 1;
                    end
                    // no change
                end
                FSM_WAIT_READ4WRITE: begin
                    if (frsp_valid_i) begin
                        logic [$clog2(WAYS)-1:0] replace_idx_tmp;
                        logic [BITS_CACHELINE-1:0] merged_data_tmp;
                        // change
                        merged_data_tmp = frsp_data_i & ~dreq_data_mask_i | dreq_data_i & dreq_data_mask_i;
                        fsm_state <= FSM_WAIT_WRITE;
                        freq_valid = 0;
                        replace_idx_tmp = sets[dreq_addr_set_id].replace_idx;
                        sets[dreq_addr_set_id].replace_idx                 <= replace_idx_tmp + 1;
                        sets[dreq_addr_set_id].ways[replace_idx_tmp].valid <= 1;
                        sets[dreq_addr_set_id].ways[replace_idx_tmp].tag   <= dreq_addr_tag;
                        sets[dreq_addr_set_id].ways[replace_idx_tmp].data  <= merged_data_tmp;
                        dreq_ready = 1;
                    end
                end
                FSM_WAIT_WRITE: begin
                    if (frsp_valid_i) begin
                        fsm_state <= FSM_IDLE;
                    end
                end
            endcase
        end

        dreq_ready_o <= dreq_ready;
        freq_valid_o <= freq_valid;
        freq_we_o    <= freq_we;
        freq_addr_o  <= freq_addr;
        freq_data_o  <= freq_data;
    end

    // Hit detection
    always_comb begin
        `define way(i) sets[dreq_addr_set_id].ways[(i)]
        for (int w = 0; w < WAYS; ++w) begin
            hits[w] = (`way(w).valid & (`way(w).tag == dreq_addr_tag));
        end
    end

    assign drsp_hit_o = dreq_valid_i & (|hits);
    assign drsp_data_o = sets[dreq_addr_set_id].ways[$clog2(hits)].data;

endmodule
