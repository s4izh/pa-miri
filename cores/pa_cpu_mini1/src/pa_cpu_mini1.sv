`timescale 1ns/1ps

module pa_cpu_mini1# (
    parameter int XLEN = 32,
    parameter int ALEN = 5,
    parameter int NREG = 32,
    parameter int ADDR_WIDTH = $clog2(NREG),
    parameter int DMEM_SIZE = 2 ** ALEN,
    parameter int IMEM_SIZE = 2 ** ALEN,
    parameter int DMEM_ADDR_WIDTH = $clog2(DMEM_SIZE),
    parameter int IMEM_ADDR_WIDTH = $clog2(IMEM_SIZE)
)(
    input  logic clk,
    input  logic reset_n,

    output logic[IMEM_ADDR_WIDTH-1:0]   imem_addr_o,
    input  logic[XLEN-1:0]              imem_data_i,

    output logic[IMEM_ADDR_WIDTH-1:0]   dmem_addr_o,
    output logic[XLEN-1:0]              dmem_data_o,
    output logic                        dmem_we_o,
    input  logic[XLEN-1:0]              dmem_data_i
);
    logic [XLEN-1:0] regs_ra_data, regs_rb_data, regs_rd_data;
    logic regs_rd_we;
    logic [ADDR_WIDTH-1:0] regs_ra_addr, regs_rb_addr, regs_rd_addr;

    regfile #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) regs (
        .clk,
        .reset_n,

        .ra_addr_i(regs_ra_addr),
        .ra_data_o(regs_ra_data),

        .rb_addr_i(regs_rb_addr),
        .rb_data_o(regs_rb_data),

        .rd_addr_i(regs_rd_addr),
        .rd_data_i(regs_rd_data),
        .rd_we_i(regs_rd_we)
    );

endmodule
