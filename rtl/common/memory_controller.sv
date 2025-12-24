import memory_controller_pkg::*;

module memory_controller #(
    parameter int XLEN = 32,
    parameter int MEM_ALEN = 12,
    parameter int MEM_DLEN = 32
) (
    input logic clk,
    input logic reset_n,

    // Core input
    input logic valid_i,
    input logic [XLEN-1:0] data_i,
    input logic [XLEN-1:0] addr_i,
    input memop_width_e width_i,
    input logic we_i,

    // Core output
    output logic valid_o,
    output logic [XLEN-1:0] data_o,
    output logic xcpt_o,

    // Mem output
    output logic [MEM_ALEN-1:0] mem_addr_o,
    output logic [MEM_DLEN-1:0] mem_data_o,
    output logic [MEM_DLEN/8-1:0] mem_byte_en_o,
    output logic mem_we_o,

    // Mem input
    input logic [XLEN-1:0] mem_data_i
);
    localparam MEM_DLEN_BYTES = MEM_DLEN/8;
    localparam MEM_DLEN_BYTES_BITS = $clog2(MEM_DLEN_BYTES);

    logic xcpt_misaligned;

    logic [MEM_DLEN_BYTES_BITS-1:0] byte_offset;
    logic [MEM_DLEN-1:0] read_data_aligned;

    assign mem_we_o = we_i & valid_i & ~xcpt_misaligned;
    assign mem_addr_o = addr_i[MEM_ALEN-1+MEM_DLEN_BYTES_BITS:MEM_DLEN_BYTES_BITS]; // addresses above 2^(MEM_ALEN+MEM_DLEN_BYTES_BITS)-1 (2^14) will wrap around
    assign valid_o = valid_i;
    assign xcpt_o = valid_i & xcpt_misaligned;
    assign byte_offset = addr_i[MEM_DLEN_BYTES_BITS-1:0];

    always_comb begin
        mem_data_o = '0;
        mem_byte_en_o = '0;
        case (width_i)
            MEMOP_WIDTH_8: begin
                mem_data_o = data_i << (byte_offset * 8);
                mem_byte_en_o = 4'b0001 << byte_offset;
            end
            MEMOP_WIDTH_16: begin
                mem_data_o = data_i << (byte_offset * 8);
                mem_byte_en_o = 4'b0011 << byte_offset;
            end
            MEMOP_WIDTH_32: begin
                mem_data_o = data_i;
                mem_byte_en_o = '1; // all ones
            end
            default: ;
        endcase
    end

    // check for exceptions
    always_comb begin
        xcpt_misaligned = 1'b0;
        case (width_i)
            MEMOP_WIDTH_16: if (addr_i[0])           xcpt_misaligned = 1'b1;
            MEMOP_WIDTH_32: if (addr_i[1:0] != 2'b0) xcpt_misaligned = 1'b1;
            MEMOP_WIDTH_INVALID:                     xcpt_misaligned = 1'b1;
            default: ;
        endcase
    end

    assign read_data_aligned = mem_data_i >> (byte_offset * 8);

    always_comb begin
        data_o = '0;
        case (width_i)
            // grab the bottom 8 bits and zero-extend
            MEMOP_WIDTH_8:  data_o = {{XLEN-8{1'b0}}, read_data_aligned[7:0]};
            // grab the bottom 16 bits and zero-extend
            MEMOP_WIDTH_16: data_o = {{XLEN-16{1'b0}}, read_data_aligned[15:0]};
            // grab 32 bits
            MEMOP_WIDTH_32: data_o = read_data_aligned[XLEN-1:0];
            // TODO: cambiar por load/store access fault creo
            MEMOP_WIDTH_INVALID: data_o = '0; // xcpt_misaligned = 1'b1;
        endcase
    end

endmodule
