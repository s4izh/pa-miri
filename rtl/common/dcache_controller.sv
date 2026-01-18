import memory_controller_pkg::*;

module dcache_controller #(
    parameter int XLEN = 32,
    parameter int BITS_CACHELINE = 128
) (
    input logic reset_n,

    // Core input
    input logic                       dreq_valid_i,
    input logic [XLEN-1:0]            dreq_addr_i,
    input logic [XLEN-1:0]            dreq_data_i,
    input memop_width_e               dreq_width_i,
    input logic                       dreq_we_i,

    // Core output
    output logic [XLEN-1:0]           drsp_data_o,
    output logic                      drsp_xcpt_o,

    // Cache output
    output logic                      creq_valid_o,
    output logic [XLEN-1:0]           creq_addr_o,
    output logic [BITS_CACHELINE-1:0] creq_data_o,
    output logic [BITS_CACHELINE-1:0] creq_data_mask_o,
    output logic                      creq_we_o,

    // Cache input
    input logic [BITS_CACHELINE-1:0]  crsp_data_i
);
    localparam OFFSET_BYTES = $clog2(XLEN/8);
    localparam OFFSET_WORDS = $clog2(BITS_CACHELINE/XLEN);

    logic xcpt_misaligned;

    logic [OFFSET_BYTES-1:0] byte_offset;
    logic [OFFSET_WORDS-1:0] word_offset;
    logic [BITS_CACHELINE-1:0] read_data_aligned;


    assign byte_offset = dreq_addr_i[OFFSET_BYTES-1:0];
    assign word_offset = dreq_addr_i[OFFSET_WORDS+OFFSET_BYTES-1:OFFSET_BYTES];

    assign creq_valid_o = dreq_valid_i & ~xcpt_misaligned;
    assign creq_we_o    = dreq_valid_i & dreq_we_i & ~xcpt_misaligned;
    assign creq_addr_o  = {dreq_addr_i[XLEN-1:OFFSET_BYTES+OFFSET_WORDS],4'b0000};
    assign drsp_xcpt_o  = dreq_valid_i & xcpt_misaligned;


    localparam int PAD = BITS_CACHELINE-XLEN;
    always_comb begin
        logic [BITS_CACHELINE-1:0] data_mask_base;

        case (dreq_width_i)
            MEMOP_WIDTH_8:  data_mask_base = {{PAD{1'b0}}, 32'h000000ff};
            MEMOP_WIDTH_16: data_mask_base = {{PAD{1'b0}}, 32'h0000ffff};
            MEMOP_WIDTH_32: data_mask_base = {{PAD{1'b0}}, 32'hffffffff};
            default: ;
        endcase

        creq_data_o = {{PAD{1'b0}}, dreq_data_i} << (word_offset * 32) << (byte_offset * 8);
        creq_data_mask_o = data_mask_base << (word_offset * 32) << (byte_offset * 8);
    end

    // check for exceptions
    always_comb begin
        xcpt_misaligned = 1'b0;
        case (dreq_width_i)
            MEMOP_WIDTH_16: if (dreq_addr_i[0])           xcpt_misaligned = 1'b1;
            MEMOP_WIDTH_32: if (dreq_addr_i[1:0] != 2'b0) xcpt_misaligned = 1'b1;
            MEMOP_WIDTH_INVALID:                          xcpt_misaligned = 1'b1;
            default: ;
        endcase
    end

    assign read_data_aligned = crsp_data_i >> (byte_offset * 8) >> (word_offset * 32);

    always_comb begin
        drsp_data_o = '0;
        case (dreq_width_i)
            // grab the bottom 8 bits and zero-extend
            MEMOP_WIDTH_8:  drsp_data_o = {{XLEN-8{1'b0}}, read_data_aligned[7:0]};
            // grab the bottom 16 bits and zero-extend
            MEMOP_WIDTH_16: drsp_data_o = {{XLEN-16{1'b0}}, read_data_aligned[15:0]};
            // grab 32 bits
            MEMOP_WIDTH_32: drsp_data_o = read_data_aligned[XLEN-1:0];
            // TODO: cambiar por load/store access fault creo
            MEMOP_WIDTH_INVALID: drsp_data_o = '0; // xcpt_misaligned = 1'b1;
        endcase
    end

endmodule
