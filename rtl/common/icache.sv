import rv_isa_pkg::*;

module icache #(
    parameter int WAYS = 4,

    // Non-modifiable (slides specify them)
    parameter int _LINES = 4,
    parameter int _CACHELINE_BYTES = 16,
) (
    input logic clk,
    input logic reset_n,

    // Interface with core (d for data)
    // Request handshake (transaction when both high)
    input  logic            dreq_valid_i,
    output logic            dreq_ready_o,
    // Request
    input  logic [XLEN-1:0] dreq_addr_i,
    // Response valid signal
    output logic            drsp_valid_o,
    // Response
    output logic [XLEN-1:0] drsp_data_o,
    output logic            drsp_xcpt_o,

    // Interface with memory (f for fill)
    // Request to memory
    output logic            freq_valid_o,
    output logic [XLEN-1:0] freq_addr_o,
    // Response from memory
    output logic            frsp_valid_i,
    output logic [(_CACHELINE_BYTES*8)-1:0] frsp_data_o
);

endmodule
