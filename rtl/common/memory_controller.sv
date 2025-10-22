module memory_controller #(
    parameter int XLEN = 32,
    parameter int ALEN = 12
) (
    input logic clk,
    input logic reset_n,

    // Core input
    input logic             valid_i,
    input logic [XLEN-1:0]  data_i,
    input logic [ALEN-1:0]  addr_i,
    input logic [1:0]       width_i, // 1, 2, 4, (unsupported)8
    input logic             we_i,

    // Core output
    output logic            valid_o,
    output logic [XLEN-1:0] data_o,

    // Mem output
    output logic [ALEN-1:0] mem_addr_o,
    output logic [XLEN-1:0] mem_data_o,
    output logic            mem_we_o,

    // Mem input
    input logic [XLEN-1:0]  mem_data_i
);

    always_comb begin
        case(width_i)
            0'b00: mem_addr_o = addr_i;
            0'b01: mem_addr_o = {addr_i[XLEN-1:1], 1'b0};
            0'b10: mem_addr_o = {addr_i[XLEN-1:2], 2'b00};
            0'b11: mem_addr_o = {addr_i[XLEN-1:3], 3'b000};
        endcase
    end

// Input:
//   - Valid
//   - Address
//   - Data (opt)
//   - Operation width
//   - Write enable

// Output:
//   - Valid
//   - Data (opt)


endmodule
