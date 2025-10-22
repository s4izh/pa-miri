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
    input logic [1:0] width_i, // 1, 2, 4, (unsupported)8
    input logic we_i,

    // Core output
    output logic valid_o,
    output logic [XLEN-1:0] data_o,
    output logic xcpt_o,

    // Mem output
    output logic [MEM_DLEN-1:0] mem_addr_o,
    output logic [MEM_ALEN-1:0] mem_data_o,
    output logic mem_we_o,

    // Mem input
    input logic [XLEN-1:0] mem_data_i
);
    logic xcpt;

    assign mem_addr_o = addr_i[MEM_ALEN-1+3:3];
    assign mem_data_o = data_i;
    assign mem_we_o = we_i & valid_i & ~xcpt;

    assign valid_o = valid_i;
    assign xcpt_o = xcpt;

    // Assign address to memory (addresses above 2^MEM_ALEN will wrap around)
    always_comb begin
        logic [2:0] offset;
        case(width_i)
            2'b00: offset = 3'b000; // Impossible to misalign a byte-sized memop
            2'b01: begin
                offset = {2'b00, addr_i[0]};
                // data_o = mem_data_i[];
            end
            2'b10: offset = {1'b0, addr_i[1:0]};
            2'b11: offset = 3'b111; // Trigger an exception
        endcase

        xcpt = (|offset) ? 1 : 0;

    end

endmodule
