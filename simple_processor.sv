// Simple Processor Module
// This is a minimal SystemVerilog processor for development environment testing

`timescale 1ns/1ps

module regfile#(
    parameter int XLEN = 32,
    parameter int NREG = 32,
    parameter int ADDR_WIDTH = $clog2(NREG)
    )(
    input logic clk,
    input logic reset_n,
    input logic [ADDR_WIDTH-1:0] ra_addr,
    input logic [ADDR_WIDTH-1:0] rb_addr,
    input logic rd_we,
    input logic [ADDR_WIDTH-1:0] rd_addr,
    input logic [XLEN-1:0] rd_data,
    output logic [XLEN-1:0] ra_data,
    output logic [XLEN-1:0] rb_data
);
    logic [NREG-1:0][XLEN-1:0] regs;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            for (int i = 0; i < NREG; ++i) begin
                regs[i] <= 0;
            end
        end else if (rd_we) begin
            regs[rd_addr] <= rd_data;
        end
    end

    assign ra_data = regs[ra_addr];
    assign rb_data = regs[rb_addr];

endmodule

module pa_cpu_mini1# (
    parameter int XLEN = 32,
    parameter int NREG = 32,
    parameter int ADDR_WIDTH = $clog2(NREG),
    parameter int DMEM_SIZE = 4096,
    parameter int IMEM_SIZE = 4096,
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

module simple_processor (
    input  logic       clk,
    input  logic       reset_n,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic       valid_out
);

    // Internal registers
    logic [7:0] accumulator;
    logic [1:0] state;
    
    // State definitions
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        LOAD  = 2'b01,
        PROC  = 2'b10,
        OUT   = 2'b11
    } state_t;
    
    state_t current_state, next_state;
    
    // State register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= IDLE;
            accumulator <= 8'h00;
        end else begin
            current_state <= next_state;
            if (current_state == LOAD) begin
                accumulator <= data_in;
            end else if (current_state == PROC) begin
                accumulator <= accumulator + 8'h01; // Simple increment operation
            end
        end
    end
    
    // Next state logic
    always_comb begin
        case (current_state)
            IDLE: next_state = LOAD;
            LOAD: next_state = PROC;
            PROC: next_state = OUT;
            OUT:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    assign data_out = accumulator;
    assign valid_out = (current_state == OUT);

endmodule
