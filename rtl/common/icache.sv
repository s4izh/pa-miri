module icache #(
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
    input  logic            dreq_valid_i,
    output logic            dreq_ready_o,
    input  logic [XLEN-1:0] dreq_addr_i,
    // Response
    output logic            drsp_hit_o,
    output logic [XLEN-1:0] drsp_data_o,
    output logic            drsp_xcpt_o,
    // Interface with memory (f for fill)
    // Request to memory
    output logic            freq_valid_o,
    output logic [XLEN-1:0] freq_addr_o,
    // Response from memory
    input  logic                      frsp_valid_i,
    input  logic [BITS_CACHELINE-1:0] frsp_data_i
);
    localparam BITS_OFFSET_ELEMENT = $clog2(BITS_CACHELINE/XLEN); // Element offset size
    localparam BITS_OFFSET  = $clog2(BITS_CACHELINE/8); // Byte offset size
    localparam BITS_LINE    = $clog2(SETS);
    localparam BITS_TAG     = XLEN - BITS_LINE - BITS_OFFSET;

    logic [BITS_OFFSET-1:0] dreq_addr_offset;
    logic [BITS_LINE-1:0]   dreq_addr_line_id;
    logic [BITS_TAG-1:0]    dreq_addr_tag;

    assign dreq_addr_offset  = dreq_addr_i[BITS_OFFSET-1:0];
    assign dreq_addr_line_id = dreq_addr_i[BITS_LINE+BITS_OFFSET-1:BITS_OFFSET];
    assign dreq_addr_tag     = dreq_addr_i[XLEN-1:BITS_LINE+BITS_OFFSET];

    typedef struct {
        logic                       valid;
        logic [BITS_TAG-1:0]        tag;
        logic [BITS_CACHELINE-1:0] data;
    } way_t;

    typedef struct {
        logic [$clog2(WAYS)-1:0] replace_idx;
        way_t                    ways[WAYS];
    } set_t;

    typedef enum {
        FSM_IDLE,
        FSM_WAIT_FRSP
    } fsm_e;

    fsm_e fsm_state;
    set_t sets[SETS];
    logic [WAYS-1:0] hits;

    // Next state logic
    always @(posedge clk) begin
        if (!reset_n) begin
            fsm_state <= FSM_IDLE;
        end else begin
            case (fsm_state)
                FSM_IDLE: begin
                    if (dreq_valid_i & ~(|hits)) begin
                        fsm_state <= FSM_WAIT_FRSP;
                    end
                end
                FSM_WAIT_FRSP: begin
                    if (frsp_valid_i) begin
                        fsm_state <= FSM_IDLE;
                    end
                end
            endcase
        end
    end

    // Actuation for FSM
    always @(posedge clk) begin
        logic            dreq_ready;
        logic            freq_valid;
        logic [XLEN-1:0] freq_addr;

        dreq_ready = dreq_ready_o;
        freq_valid = freq_valid_o;
        freq_addr  = freq_addr_o;

        if (!reset_n) begin
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
                        // change
                        freq_valid = 1;
                        freq_addr  = { dreq_addr_tag, dreq_addr_line_id, {BITS_OFFSET{1'b0}} };
                        dreq_ready = 0;
                    end else begin
                        // no change
                        freq_valid = 0;
                        dreq_ready = 1;
                    end
                end
                FSM_WAIT_FRSP: begin
                    if (frsp_valid_i) begin
                        // change
                        logic [$clog2(WAYS)-1:0] replace_idx_tmp;
                        freq_valid = 0;
                        replace_idx_tmp = sets[dreq_addr_line_id].replace_idx;
                        sets[dreq_addr_line_id].replace_idx                 <= replace_idx_tmp + 1;
                        sets[dreq_addr_line_id].ways[replace_idx_tmp].valid <= 1;
                        sets[dreq_addr_line_id].ways[replace_idx_tmp].tag   <= dreq_addr_tag;
                        sets[dreq_addr_line_id].ways[replace_idx_tmp].data  <= frsp_data_i;
                        dreq_ready = 1;
                    end else begin
                        // no change
                        // keep signals high
                        freq_valid = 1;
                        freq_addr  = { dreq_addr_tag, dreq_addr_line_id, {BITS_OFFSET{1'b0}} };
                        dreq_ready = 0;
                    end
                end
            endcase
        end

        dreq_ready_o <= dreq_ready;
        freq_valid_o <= freq_valid;
        freq_addr_o  <= freq_addr;
    end

    // Hit detection
    always_comb begin
        `define way(i) sets[dreq_addr_line_id].ways[(i)]
        for (int w = 0; w < WAYS; ++w) begin
            hits[w] = (`way(w).valid & (`way(w).tag == dreq_addr_tag));
        end
        `undef way
    end

    assign drsp_hit_o = dreq_valid_i & (|hits);

    // Data alignment
    logic [BITS_OFFSET_ELEMENT-1:0] data_o_idx;
    assign data_o_idx = dreq_addr_offset[BITS_OFFSET-1 -: BITS_OFFSET_ELEMENT];
    logic [BITS_CACHELINE-1:0] data_o_tmp;
    assign data_o_tmp = sets[dreq_addr_line_id].ways[$clog2(hits)].data;
    assign drsp_data_o = data_o_tmp[(XLEN*(int'(data_o_idx)+1))-1 -: XLEN];

endmodule
