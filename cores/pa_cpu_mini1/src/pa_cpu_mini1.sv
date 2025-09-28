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
        .clk(clk),
        .reset_n(reset_n),
        .ra_addr(regs_ra_addr),
        .rb_addr(regs_rb_addr),
        .rd_we(regs_rd_we),
        .rd_addr(regs_rd_addr),
        .rd_data(regs_rd_data),
        .ra_data(regs_ra_data),
        .rb_data(regs_rb_data)
    );

    regfile #(
        .XLEN(XLEN),
        .NREG(IMEM_SIZE)
    ) imem (
        .clk(clk),
        .reset_n(reset_n),
        .ra_addr(imem_ra_addr),
        .rb_addr(IMEM_ADDR_WIDTH'(0)),
        .rd_we(1'b0),
        .rd_addr(imem_rd_addr),
        .rd_data(imem_rd_data),
        .ra_data(imem_ra_data)
        // .rb_data(XLEN'(0))
    );

    regfile #(
        .XLEN(XLEN),
        .NREG(DMEM_SIZE)
    ) dmem (
        .clk(clk),
        .reset_n(reset_n),
        .ra_addr(dmem_ra_addr),
        .rb_addr(DMEM_ADDR_WIDTH'(0)),
        .rd_we(dmem_rd_we),
        .rd_addr(dmem_rd_addr),
        .rd_data(dmem_rd_data),
        .ra_data(dmem_ra_data)
        // .rb_data(XLEN'(0))
    );

endmodule
