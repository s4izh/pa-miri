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

    output logic                mem_valid_o,
    output logic [MEM_ALEN-1:0] mem_addr_o,
    output logic [MEM_DLEN-1:0] mem_data_o,
    output logic                mem_we_o,
    input  logic [MEM_DLEN-1:0] mem_data_i,
    input  logic                mem_valid_i
);
    localparam int BITS_CACHELINE = MEM_DLEN;

    logic [XLEN-1:0] hart_imem_addr, hart_dmem_addr;
    logic [XLEN-1:0] mem_addr_arb;

    logic                      imem_valid_o;
    logic [XLEN-1:0]           imem_addr_o;
    logic                      imem_valid_i;
    logic [BITS_CACHELINE-1:0] imem_data_i;

    logic                      dmem_valid_o;
    logic [XLEN-1:0]           dmem_addr_o;
    logic [BITS_CACHELINE-1:0] dmem_data_o;
    logic                      dmem_we_o;
    logic                      dmem_valid_i;
    logic [BITS_CACHELINE-1:0] dmem_data_i;

    // Convert from core-address (XLEN, BYTE-addressable) to memory-address (MEM_ALEN, MEM_DLEN-addressable)
    //           31       23       15        7      0
    // core addr: xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
    // mem  addr:                   xxxxxxxx xxxx
    assign mem_addr_o = mem_addr_arb[MEM_ALEN+$clog2(MEM_DLEN/8)-1 -: MEM_ALEN];

    memory_arbitrer #(
        .XLEN(32),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) memory_arbitrer_inst (
        .clk,
        .reset_n,

        // interface icache
        .ic_freq_valid_i(imem_valid_o),
        .ic_freq_addr_i(hart_imem_addr),
        .ic_frsp_valid_o(imem_valid_i),
        .ic_frsp_data_o(imem_data_i),

        // interface dcache
        .dc_freq_valid_i(dmem_valid_o),
        .dc_freq_addr_i(hart_dmem_addr),
        .dc_freq_we_i(dmem_we_o),
        .dc_freq_data_i(dmem_data_o),
        .dc_frsp_valid_o(dmem_valid_i),
        .dc_frsp_data_o(dmem_data_i),

        .mem_valid_o,
        .mem_addr_o(mem_addr_arb),
        .mem_we_o,
        .mem_data_o,
        .mem_valid_i,
        .mem_data_i
    );

    gandul #(
        .XLEN(XLEN),
        .WAYS(CACHE_WAYS),
        .SETS(CACHE_SETS),
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
        .dmem_valid_i,
        .dmem_data_i
    );

endmodule
