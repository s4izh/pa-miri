module icache #(
    parameter int XLEN = 32,
    parameter int WAYS = 4,

    // Non-modifiable (slides specify them)
    parameter int _LINES = 4,
    parameter int _CACHELINE_BYTES = 16
) (
    input logic clk,
    input logic reset_n,

    // Interface with core (d for data)
    // Request
    input  logic            dreq_valid_i,
    output logic            dreq_ready_o,
    input  logic [XLEN-1:0] dreq_addr_i,
    // Response
    output logic [XLEN-1:0] drsp_data_o,
    output logic            drsp_xcpt_o,
    // ^^^^
    // No need for drsp_valid_o signal. Since we don't support outstanding
    // requests, we can know if the output is valid by using (~dreq_ready_o).

    // Interface with memory (f for fill)
    // Request to memory
    output logic            freq_valid_o,
    output logic [XLEN-1:0] freq_addr_o,
    // Response from memory
    input  logic                            frsp_valid_i,
    input  logic [(_CACHELINE_BYTES*8)-1:0] frsp_data_i
);
    localparam BITS_DATA    = _CACHELINE_BYTES*8;

    localparam BITS_OFFSET  = $clog2(_CACHELINE_BYTES);
    localparam BITS_LINE    = $clog2(_LINES);
    localparam BITS_TAG     = XLEN - BITS_LINE - BITS_OFFSET;

    logic [BITS_OFFSET-1:0] dreq_addr_offset;
    logic [BITS_LINE-1:0]   dreq_addr_line_id;
    logic [BITS_TAG-1:0]    dreq_addr_tag;

    assign dreq_addr_offset  = dreq_addr_i[BITS_OFFSET-1:0];
    assign dreq_addr_line_id = dreq_addr_i[BITS_LINE+BITS_OFFSET-1:BITS_OFFSET];
    assign dreq_addr_tag     = dreq_addr_i[XLEN-1:BITS_LINE+BITS_OFFSET];

    typedef struct {
        logic                 valid;
        logic [BITS_TAG-1:0]  tag;
        logic [BITS_DATA-1:0] data;
    } way_t;

    typedef struct {
        way_t ways[WAYS];
    } line_t;

    typedef enum {
        FSM_IDLE,
        FSM_WAIT_FRSP
    } fsm_e;

    fsm_e fsm_state;
    line_t lines [_LINES];
    logic [WAYS-1:0] hits;

    // Next state logic
    always @(posedge clk) begin
        if (!reset_n) begin
            fsm_state <= FSM_IDLE;
            for (int l = 0; l < _LINES; ++l) begin
                for (int w = 0; w < WAYS; ++w) begin
                    lines[l].ways[w].valid <= 0;
                end
            end
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
            for (int l = 0; l < _LINES; ++l) begin
                for (int w = 0; w < WAYS; ++w) begin
                    lines[l].ways[w].valid <= 0;
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
                        freq_valid = 0;
                        lines[dreq_addr_line_id].ways[0].valid <= 1;
                        lines[dreq_addr_line_id].ways[0].tag   <= dreq_addr_tag;
                        lines[dreq_addr_line_id].ways[0].data  <= frsp_data_i;
                        dreq_ready = 1;
                    end else begin
                        // no change
                        // freq_valid = 0;
                        // TODO remove this next two lines and use the previous one
                        freq_valid = 1;
                        freq_addr  = dreq_addr_i;
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
        for (int w = 0; w < WAYS; ++w) begin
            way_t way = lines[dreq_addr_line_id].ways[w];
            assign hits[w] = (way.valid & (way.tag == dreq_addr_tag));
        end
    end

endmodule
