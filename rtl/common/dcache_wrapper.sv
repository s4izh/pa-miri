import memory_controller_pkg::*;
`include "harness_params.svh"

module dcache_wrapper #(
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
    input  logic            dreq_valid_i,
    output logic            dreq_ready_o,
    input  logic [XLEN-1:0] dreq_addr_i,
    input  logic [XLEN-1:0] dreq_data_i,
    input  logic            dreq_we_i,
    input  memop_width_e    dreq_width_i,
    // Response
    output logic [XLEN-1:0] drsp_data_o,
    output logic            drsp_xcpt_o,
    // Interface with memory (f for fill)
    // Request to memory
    output logic                      freq_valid_o,
    output logic                      freq_we_o,
    output logic [BITS_CACHELINE-1:0] freq_data_o,
    output logic [XLEN-1:0]           freq_addr_o,
    // Response from memory
    input  logic                      frsp_valid_i,
    input  logic [BITS_CACHELINE-1:0] frsp_data_i
);
    logic                      creq_valid;
    logic [XLEN-1:0]           creq_addr;
    logic [BITS_CACHELINE-1:0] creq_data;
    logic [BITS_CACHELINE-1:0] creq_data_mask;
    logic                      creq_we;
    logic [BITS_CACHELINE-1:0] crsp_data;

    dcache_controller #(
        .XLEN(XLEN),
        .BITS_CACHELINE(BITS_CACHELINE)
    ) dcache_ctrl_inst (
        .reset_n,
        // Core input
        .dreq_valid_i,
        .dreq_addr_i,
        .dreq_width_i,
        .dreq_data_i,
        .dreq_we_i,
        // Core output
        .drsp_data_o,
        .drsp_xcpt_o,
        // To Cache input
        .creq_valid_o(creq_valid),
        .creq_addr_o(creq_addr),
        .creq_data_o(creq_data),
        .creq_data_mask_o(creq_data_mask),
        .creq_we_o(creq_we),
        // Cache input
        .crsp_data_i(crsp_data)
    );

    `define DCACHE_PARAMS \
        .XLEN(XLEN), \
        .WAYS(WAYS), \
        .SETS(SETS), \
        .BITS_CACHELINE(BITS_CACHELINE)

    `define DCACHE_PORTS \
        .clk(clk), \
        .reset_n(reset_n), \
        .dreq_valid_i(creq_valid), \
        .dreq_ready_o(dreq_ready_o), \
        .dreq_addr_i(creq_addr), \
        .dreq_we_i(creq_we), \
        .dreq_data_i(creq_data), \
        .dreq_data_mask_i(creq_data_mask), \
        .drsp_data_o(crsp_data), \
        .freq_valid_o(freq_valid_o), \
        .freq_we_o(freq_we_o), \
        .freq_data_o(freq_data_o), \
        .freq_addr_o(freq_addr_o), \
        .frsp_valid_i(frsp_valid_i), \
        .frsp_data_i(frsp_data_i)


    localparam string POLICY = `DCACHE_STORE_POLICY;

    generate
        if (POLICY == "wt") begin : gen_wt
            dcache_engine_wt #(`DCACHE_PARAMS) dcache_inst ( `DCACHE_PORTS );
        end 
        else begin : gen_wb
            dcache_engine_wb #(`DCACHE_PARAMS) dcache_inst ( `DCACHE_PORTS );
        end
    endgenerate

    `undef DCACHE_PARAMS
    `undef DCACHE_PORTS

endmodule
