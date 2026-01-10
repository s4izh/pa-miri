module memory_arbitrer #(
    parameter int XLEN = 32,
    parameter int BITS_CACHELINE = 128
) (
    input logic clk,
    input logic reset_n,

    // interface icache
    input  logic                      ic_freq_valid_i,
    input  logic [XLEN-1:0]           ic_freq_addr_i,
    output logic                      ic_frsp_valid_o,
    output logic [BITS_CACHELINE-1:0] ic_frsp_data_o,

    // interface dcache
    input  logic                      dc_freq_valid_i,
    input  logic [XLEN-1:0]           dc_freq_addr_i,
    input  logic                      dc_freq_we_i,
    input  logic [BITS_CACHELINE-1:0] dc_freq_data_i,
    output logic                      dc_frsp_valid_o,
    output logic [BITS_CACHELINE-1:0] dc_frsp_data_o,

    // interface mem
    output logic                      mem_valid_o,
    output logic [XLEN-1:0]           mem_addr_o,
    output logic                      mem_we_o,
    output logic [BITS_CACHELINE-1:0] mem_data_o,
    input  logic                      mem_valid_i,
    input  logic [BITS_CACHELINE-1:0] mem_data_i
);

    typedef enum logic [1:0] {
        IDLE,
        SERVING_D,
        SERVING_I
    } state_e;

    state_e state, next_state;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) state <= IDLE;
        else          state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (dc_freq_valid_i)      next_state = SERVING_D;
                else if (ic_freq_valid_i) next_state = SERVING_I;
            end
            SERVING_D: if (mem_valid_i)   next_state = IDLE;
            SERVING_I: if (mem_valid_i)   next_state = IDLE;
            default:                      next_state = IDLE;
        endcase
    end

    always_comb begin
        mem_valid_o   = 1'b0;
        mem_we_o    = 1'b0;
        mem_addr_o  = '0;
        mem_data_o = '0;

        ic_frsp_valid_o = 1'b0;
        ic_frsp_data_o  = mem_data_i;
        dc_frsp_valid_o = 1'b0;
        dc_frsp_data_o  = mem_data_i;

        case (state)
            SERVING_D: begin
                mem_valid_o     = 1'b1;
                mem_we_o        = dc_freq_we_i;
                mem_addr_o      = {dc_freq_addr_i[XLEN-1:4], 4'b0000};
                mem_data_o      = dc_freq_data_i;
                dc_frsp_valid_o = mem_valid_i;
            end

            SERVING_I: begin
                mem_valid_o     = 1'b1;
                mem_we_o        = 1'b0;
                mem_addr_o      = {ic_freq_addr_i[XLEN-1:4], 4'b0000};
                ic_frsp_valid_o = mem_valid_i;
            end
            
            default: ;
        endcase
    end

endmodule
