import memory_controller_pkg::*;
import rv_isa_pkg::*;

module soc #(
    parameter int XLEN = 32,
    parameter int IALEN = 12,
    parameter int DALEN = 12,
    parameter int IMEM_DLEN = 128,
    parameter int DMEM_DLEN = 32,
    parameter int WAYS = 4,
    parameter int SETS = 4,
    parameter int BITS_CACHELINE = 128
) (
    input  logic clk,
    input  logic reset_n,

    output logic                    imem_valid_o,
    output logic [IALEN-1:0]        imem_addr_o,
    input  logic [IMEM_DLEN-1:0]    imem_data_i,
    input  logic                    imem_valid_i,

    output logic                    dmem_valid_o,
    output logic [DALEN-1:0]        dmem_addr_o,
    output logic [DMEM_DLEN-1:0]    dmem_data_o,
    output logic                    dmem_we_o,
    input  logic [DMEM_DLEN-1:0]    dmem_data_i,
    input  logic                    dmem_valid_i
);

    logic hart_imem_valid_to_mem, hart_imem_valid_to_hart;
    logic [XLEN-1:0] hart_imem_addr;
    logic [IMEM_DLEN-1:0] hart_imem_data_ld;

    logic [XLEN-1:0] hart_dmem_addr, hart_dmem_data_st, hart_dmem_data_ld;
    logic hart_dmem_we, hart_dmem_memop_valid;
    memop_width_e hart_dmem_width;
    logic imem_xcpt, dmem_xcpt;

    rv_pa3 #(
        .XLEN(XLEN)
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) hart0_inst (
        .clk,
        .reset_n,

        .imem_valid_o,
        .imem_addr_o(hart_imem_addr),
        .imem_valid_i,
        .imem_data_i,

        .dmem_valid_o,
        .dmem_addr_o(hart_dmem_addr),
        .dmem_data_o,
        .dmem_we_o,
        .dmem_data_i,
        .dmem_valid_i,
    );

    assign imem_addr_o = hart_imem_addr[IALEN+2-1 -: IALEN];
    assign dmem_addr_o = hart_dmem_addr[DALEN+2-1 -: DALEN];

endmodule
