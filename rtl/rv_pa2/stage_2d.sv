module stage_2d #(
    parameter int XLEN = 32,
    parameter int NREG = 32
) (
    input logic clk,
    input logic reset_n,
    // Pipeline input/output
    input  signals_fetch_t  _i,
    output signals_decode_t _o,
    // Write-back
    input logic                    rd_we_i,
    input logic [$clog2(NREG)-1:0] rd_addr_i,
    input logic [XLEN-1:0]         rd_data_i,
    // Exceptions
    output logic xcpt_illegal_ins_o
);

    logic [$clog2(NREG)-1:0] rs1_addr, rs2_addr;

    assign _o.pc = _i.pc;

    rv_decoder #(
        .XLEN(XLEN)
    ) dec_inst (
        .ins_i(_i.ins),

        .alu_op_o(_o.alu_op),
        .alu_op1_sel_o(_o.alu_op1_sel),
        .alu_op2_sel_o(_o.alu_op2_sel),
        .wb_sel_o(_o.wb_sel),

        .pc_sel_o(_o.pc_sel),
        .illegal_ins_o(xcpt_illegal_ins_o),

        .is_wb_o(_o.is_wb),
        .is_ld_o(_o.is_ld),
        .is_st_o(_o.is_st),

        .rs1_addr_o(rs1_addr),
        .rs2_addr_o(rs2_addr),
        .rd_addr_o(_o.rd_addr),
        .immed_o(_o.immed),

        .compare_op_o(_o.compare_op),
        .memop_width_o(_o.memop_width),
        .ld_unsigned_o(_o.ld_unsigned)
    );

    rv_regfile #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) regs_inst (
        .clk,
        .reset_n,

        .rs1_addr_i(rs1_addr),
        .rs1_data_o(_o.rs1_data),

        .rs2_addr_i(rs2_addr),
        .rs2_data_o(_o.rs2_data),

        .rd_addr_i(rd_addr_i),
        .rd_data_i(rd_data_i),
        .rd_we_i(rd_we_i)
    );

endmodule
