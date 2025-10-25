module soc #(
    parameter int XLEN = 32,
    parameter int IALEN = 12,
    parameter int DALEN = 12,
    parameter int MEM_DLEN = 32
) (
    input clk,
    input reset_n,

    output logic [MEM_ALEN-1:0] imem_addr_o,
    input  logic [MEM_DLEN-1:0] imem_data_i,

    output logic [MEM_ALEN-1:0] dmem_addr_o,
    output logic [MEM_DLEN-1:0] dmem_data_o,
    input logic [MEM_DLEN-1:0] dmem_data_i,
    output logic [MEM_DLEN/8-1:0] dmem_byte_en_o,
    output logic dmem_we_o,
);

    rv_processor_a1_unicycle #(
        .XLEN(XLEN),
        .IALEN(IALEN),
        .XLEN(DALEN),
    ) hart0_inst (
        .clk,
        .reset_n,
        .imem_addr_o,
        .imem_data_i,

        .dmem_addr_o,
        .dmem_data_o,
        .dmem_we_o,
        .dmem_data_i
    );

memory_controller #(
    .XLEN(XLEN),
    .MEM_ALEN(DALEN),
    .MEM_DLEN(XLEN)
) dmem_controller_inst (
    .clk,
    .reset_n,

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

endmodule
