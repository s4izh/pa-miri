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
    input logic clk,
    input logic reset_n
);
    logic [XLEN-1:0] regs_ra_data, regs_rb_data, regs_rd_data;
    logic regs_rd_we;
    logic [ADDR_WIDTH-1:0] regs_ra_addr, regs_rb_addr, regs_rd_addr;

    logic [XLEN-1:0] imem_ra_data, imem_rd_data;
    logic imem_rd_we;
    logic [IMEM_ADDR_WIDTH-1:0] imem_ra_addr, imem_rd_addr;

    logic [XLEN-1:0] dmem_ra_data, dmem_rd_data;
    logic dmem_rd_we;
    logic [DMEM_ADDR_WIDTH-1:0] dmem_ra_addr, dmem_rd_addr;

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

    regfile #(
        .XLEN(XLEN),
        .NREG(IMEM_SIZE)
    ) imem (
        .clk,
        .reset_n,

        .ra_addr_i(imem_ra_addr),
        .ra_data_o(imem_ra_data),

        .rb_addr_i(IMEM_ADDR_WIDTH'(0)),
        // .rb_data_o(XLEN'(0)),

        .rd_addr_i(imem_rd_addr),
        .rd_data_i(imem_rd_data),
        .rd_we_i(1'b0)
    );

    regfile #(
        .XLEN(XLEN),
        .NREG(DMEM_SIZE)
    ) dmem (
        .clk,
        .reset_n,

        .ra_addr_i(dmem_ra_addr),
        .ra_data_o(dmem_ra_data),

        .rb_addr_i(DMEM_ADDR_WIDTH'(0)),
        // .rb_data_i(XLEN'(0))

        .rd_addr_i(dmem_rd_addr),
        .rd_data_i(dmem_rd_data),
        .rd_we_i(dmem_rd_we)
    );

endmodule
