import memory_controller_pkg::*;
import rv_isa_pkg::*;

module soc #(
    parameter int XLEN = 32,
    parameter int IALEN = 12,
    parameter int DALEN = 12,
    parameter int IMEM_DLEN = 128,
    parameter int DMEM_DLEN = 32
) (
    input  logic clk,
    input  logic reset_n,

    output logic [IALEN-1:0]        imem_addr_o,
    input  logic [IMEM_DLEN-1:0]    imem_data_i,

    output logic [DALEN-1:0]        dmem_addr_o,
    output logic [DMEM_DLEN-1:0]    dmem_data_o,
    output logic [DMEM_DLEN/8-1:0]  dmem_byte_en_o,
    output logic                    dmem_we_o,
    input  logic [DMEM_DLEN-1:0]    dmem_data_i
);

    logic hart_imem_valid_to_mem, hart_imem_valid_to_hart;
    logic [XLEN-1:0] hart_imem_addr;
    logic [IMEM_DLEN-1:0] hart_imem_data_ld;

    logic [XLEN-1:0] hart_dmem_addr, hart_dmem_data_st, hart_dmem_data_ld;
    logic hart_dmem_we, hart_dmem_memop_valid;
    memop_width_e hart_dmem_width;
    trap_t hart_imem_trap, hart_dmem_trap;
    logic imem_xcpt, dmem_xcpt;

    assign hart_imem_trap.valid     = imem_xcpt;
    assign hart_imem_trap.trap_type = TRAP_TYPE_EXCEPTION;
    assign hart_imem_trap.cause     = EXC_CAUSE_INSTR_ADDR_MISALIGNED;

    assign hart_dmem_trap.valid     = dmem_xcpt;
    assign hart_dmem_trap.trap_type = TRAP_TYPE_EXCEPTION;
    assign hart_dmem_trap.cause     = EXC_CAUSE_INSTR_ADDR_MISALIGNED;

    rv_pa3 #(
        .XLEN(XLEN)
    ) hart0_inst (
        .clk,
        .reset_n,
        .imem_valid_o(hart_imem_valid_to_mem),
        .imem_addr_o(hart_imem_addr),
        .imem_valid_i(hart_imem_valid_to_hart),
        .imem_data_i(hart_imem_data_ld),
        .imem_trap_i(hart_imem_trap),

        .dmem_width_o(hart_dmem_width),
        .dmem_memop_valid_o(hart_dmem_memop_valid),
        .dmem_addr_o(hart_dmem_addr),
        .dmem_data_o(hart_dmem_data_st),
        .dmem_we_o(hart_dmem_we),
        .dmem_data_i(hart_dmem_data_ld),
        .dmem_trap_i(hart_dmem_trap)
    );

    assign imem_addr_o = hart_imem_addr[IALEN+2-1 -: IALEN];
    assign hart_imem_valid_to_hart = hart_imem_valid_to_mem;
    assign hart_imem_data_ld = imem_data_i;
    // .imem_trap_i(hart_imem_trap),

    // memory_controller #(
    //     .XLEN(XLEN),
    //     .MEM_ALEN(IALEN),
    //     .MEM_DLEN(IMEM_DLEN)
    // ) imem_controller_inst (
    //     .clk,
    //     .reset_n,
    //
    //     // Input from core
    //     .valid_i(hart_imem_valid_to_mem),
    //     .data_i('0),
    //     .addr_i(hart_imem_addr),
    //     .width_i(hart_memop_width),
    //     .we_i(0),
    //
    //     // Output to core
    //     .valid_o(hart_imem_valid_to_hart),
    //     .data_o(hart_imem_data_ld),
    //     .xcpt_o(imem_xcpt),
    //
    //     // Output to mem
    //     .mem_addr_o(imem_addr_o),
    //     .mem_data_o(),
    //     .mem_byte_en_o(),
    //     .mem_we_o(),
    //
    //     // Input from mem
    //     .mem_data_i(imem_data_i)
    // );

    memory_controller #(
        .XLEN(XLEN),
        .MEM_ALEN(DALEN),
        .MEM_DLEN(DMEM_DLEN)
    ) dmem_controller_inst (
        .clk,
        .reset_n,

        // Input from core
        .valid_i(hart_dmem_memop_valid),
        .data_i(hart_dmem_data_st),
        .addr_i(hart_dmem_addr),
        .width_i(hart_dmem_width),
        .we_i(hart_dmem_we),

        // Output to core
        .valid_o(),
        .data_o(hart_dmem_data_ld),
        .xcpt_o(dmem_xcpt),

        // Output to memory
        .mem_addr_o(dmem_addr_o),
        .mem_data_o(dmem_data_o),
        .mem_byte_en_o(dmem_byte_en_o),
        .mem_we_o(dmem_we_o),

        // Input from memory
        .mem_data_i(dmem_data_i)
    );

endmodule
