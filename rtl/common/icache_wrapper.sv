import memory_controller_pkg::*;

module icache_wrapper #(
    parameter int XLEN = 32,
    parameter int WAYS = 4,

    // Non-modifiable (slides specify them)
    parameter int SETS = 4,
    parameter int BITS_CACHELINE = 128
) (
    input logic clk,
    input logic reset_n,

    // Interface with core (d for data)
    // Request
    input  logic                      dreq_valid_i,
    output logic                      dreq_ready_o,
    input  logic [XLEN-1:0]           dreq_addr_i,
    input  memop_width_e              dreq_width_i,
    // Response
    output logic [XLEN-1:0]           drsp_data_o,
    output logic                      drsp_xcpt_o,
    // Interface with memory (f for fill)
    // Request to memory
    output logic                      freq_valid_o,
    output logic [XLEN-1:0]           freq_addr_o,
    // Response from memory
    input  logic                      frsp_valid_i,
    input  logic [BITS_CACHELINE-1:0] frsp_data_i
);
    logic                      creq_valid;
    logic [XLEN-1:0]           creq_addr;
    logic [BITS_CACHELINE-1:0] crsp_data;

    icache_controller #(
        .XLEN(XLEN),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) icache_ctrl_inst (
        .reset_n,
        // IF with core
        .dreq_valid_i,
        .dreq_addr_i,
        .dreq_width_i,
        .drsp_data_o,
        .drsp_xcpt_o,
        // IF with cache
        .creq_valid_o(creq_valid),
        .creq_addr_o(creq_addr),
        .crsp_data_i(crsp_data)
    );

    icache #(
        .XLEN(XLEN),
        .WAYS(WAYS),
        .SETS(SETS),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) icache_inst (
        .clk,
        .reset_n,
        // IF with core/controller
        .dreq_valid_i(creq_valid),
        .dreq_ready_o,
        .dreq_addr_i(creq_addr),
        .drsp_data_o(crsp_data),
        // IF with memory
        .freq_valid_o,
        .freq_addr_o,
        .frsp_valid_i,
        .frsp_data_i
    );

endmodule
