import memory_controller_pkg::*;

module soc #(
    parameter int XLEN = 32,
    parameter int IALEN = 12,
    parameter int DALEN = 12,
    parameter int MEM_DLEN = 32
) (
    input  logic clk,
    input  logic reset_n,

    output logic [IALEN-1:0]        imem_addr_o,
    input  logic [MEM_DLEN-1:0]     imem_data_i,

    output logic [DALEN-1:0]        dmem_addr_o,
    output logic [MEM_DLEN-1:0]     dmem_data_o,
    output logic [MEM_DLEN/8-1:0]   dmem_byte_en_o,
    output logic                    dmem_we_o,
    input  logic [MEM_DLEN-1:0]     dmem_data_i
);

    logic [XLEN-1:0] hart_imem_addr, hart_imem_data_ld;

    logic [XLEN-1:0] hart_dmem_addr, hart_dmem_data_st, hart_dmem_data_ld;
    logic hart_dmem_we, hart_dmem_memop_valid;
    memop_width_e hart_dmem_width;

    rv_processor_a1_unicycle #(
        .XLEN(XLEN)
    ) hart0_inst (
        .clk,
        .reset_n,
        .imem_addr_o(hart_imem_addr),
        .imem_data_i(hart_imem_data_ld),

        .dmem_width_o(hart_dmem_width), // TODO
        .dmem_memop_valid_o(hart_dmem_memop_valid), // TODO
        .dmem_addr_o(hart_dmem_addr),
        .dmem_data_o(hart_dmem_data_st),
        .dmem_we_o(hart_dmem_we),
        .dmem_data_i(hart_dmem_data_ld)
    );

memory_controller #(
    .XLEN(XLEN),
    .MEM_ALEN(IALEN),
    .MEM_DLEN(XLEN)
) imem_controller_inst (
    .clk,
    .reset_n,

    // Core input
    .valid_i(1),
    .data_i('0),
    .addr_i(hart_imem_addr),
    .width_i(MEMOP_WIDTH_32),
    .we_i(0),

    // Core output
    // .valid_o(),
    .data_o(hart_imem_data_ld),
    // .xcpt_o(),

    // Mem output
    .mem_addr_o(imem_addr_o),
    // .mem_data_o(),
    // .mem_byte_en_o(),
    // .mem_we_o(),

    // Mem input
    .mem_data_i(imem_data_i)
);

memory_controller #(
    .XLEN(XLEN),
    .MEM_ALEN(DALEN),
    .MEM_DLEN(XLEN)
) dmem_controller_inst (
    .clk,
    .reset_n,

    // Core input
    .valid_i(hart_dmem_memop_valid),
    .data_i(hart_dmem_data_st),
    .addr_i(hart_dmem_addr),
    .width_i(hart_dmem_width),
    .we_i(hart_dmem_we),

    // Core output
    // .valid_o(),
    .data_o(hart_dmem_data_ld),
    // .xcpt_o(),

    // Mem output
    .mem_addr_o(dmem_addr_o),
    .mem_data_o(dme_data_o),
    .mem_byte_en_o(dmem_byte_en_o),
    .mem_we_o(dmem_we_o),

    // Mem input
    .mem_data_i(dmem_data_i)
);

endmodule
