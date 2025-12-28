import memory_controller_pkg::*;
import rv_isa_pkg::*;

module soc #(
    parameter int XLEN = 32,
    parameter int MEM_ALEN = 12,
    parameter int MEM_DLEN = 128,
    parameter int CACHE_WAYS = 4,
    parameter int CACHE_SETS = 4
) (
    input  logic clk,
    input  logic reset_n,

    output logic                imem_valid_o,
    output logic [MEM_ALEN-1:0] imem_addr_o,
    input  logic [MEM_DLEN-1:0] imem_data_i,
    input  logic                imem_valid_i,

    output logic                dmem_valid_o,
    output logic [MEM_ALEN-1:0] dmem_addr_o,
    output logic [MEM_DLEN-1:0] dmem_data_o,
    output logic                dmem_we_o,
    input  logic [MEM_DLEN-1:0] dmem_data_i,
    input  logic                dmem_valid_i
);

    logic [XLEN-1:0] hart_imem_addr, hart_dmem_addr;

    // Convert from core-address (XLEN, BYTE-addressable) to memory-address (MEM_ALEN, MEM_DLEN-addressable)
    //           31       23       15        7      0
    // core addr: xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
    // mem  addr:                   xxxxxxxx xxxx

    assign imem_addr_o = hart_imem_addr[MEM_ALEN+$clog2(MEM_DLEN/8)-1 -: MEM_ALEN];
    assign dmem_addr_o = hart_dmem_addr[MEM_ALEN+$clog2(MEM_DLEN/8)-1 -: MEM_ALEN];

    // IDEA: When unified memory is here, check if the address is within the
    // bounds of a valid device (like the DRAM, ROM, or whatever), but define
    // an addressable space, and enfoce it, instead of wrapping around :P
    // This could be done by a module placed between the arbitrer and the
    // memory: kind of like a memory controller (could live at the soc level)

    rv_pa3 #(
        .XLEN(XLEN),
        .WAYS(CACHE_WAYS),
        .SETS(CACHE_SETS),
        .BITS_CACHELINE(MEM_DLEN)
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
        .dmem_valid_i,
        .dmem_data_i
    );

endmodule
