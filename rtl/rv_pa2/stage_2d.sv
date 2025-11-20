import rv_datapath_pkg::*;

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
    output logic xcpt_illegal_ins_o,
    // Hazard detection
    input  logic                    noop_i,
    input  logic                    stall_i,
    output logic [$clog2(NREG)-1:0] rs1_addr_o,
    output logic                    rs1_valid_o,
    output logic [$clog2(NREG)-1:0] rs2_addr_o,
    output logic                    rs2_valid_o
);
    `define PROPAGATE(signal) assign _o.signal = _i.signal

    logic [$clog2(NREG)-1:0] rs1_addr, rs2_addr;
    logic is_wb, is_st;
    mux_pc_sel_e pc_sel;

    logic [XLEN-1:0] rf_rs1_data, rf_rs2_data;

    `PROPAGATE(ins);
    `PROPAGATE(pc);

    assign rs1_addr_o = rs1_addr;
    assign rs2_addr_o = rs2_addr;

    always_comb begin
        if (noop_i || stall_i) begin
            _o.valid  = 0;
            _o.is_wb  = 0;
            _o.is_st  = 0;
            _o.pc_sel = MUX_PC_NEXT;
            // _o.ins = 32'h00000033; // noop (add x0, x0, x0)
        end else begin
            _o.valid  = _i.valid;
            _o.is_wb  = is_wb;
            _o.is_st  = is_st;
            _o.pc_sel = pc_sel;
            // _o.ins    = _i.ins;
        end
    end

    rv_decoder #(
        .XLEN(XLEN)
    ) dec_inst (
        .ins_i(_i.ins),

        .alu_op_o(_o.alu_op),
        .alu_op1_sel_o(_o.alu_op1_sel),
        .alu_op2_sel_o(_o.alu_op2_sel),
        .wb_sel_o(_o.wb_sel),

        .pc_sel_o(pc_sel),
        .illegal_ins_o(xcpt_illegal_ins_o),

        .is_wb_o(is_wb),
        .is_ld_o(_o.is_ld),
        .is_st_o(is_st),

        .rs1_addr_o(rs1_addr),
        .rs1_valid_o(rs1_valid_o),
        .rs2_addr_o(rs2_addr),
        .rs2_valid_o(rs2_valid_o),
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
        .rs1_data_o(rf_rs1_data),

        .rs2_addr_i(rs2_addr),
        .rs2_data_o(rf_rs2_data),

        .rd_addr_i(rd_addr_i),
        .rd_data_i(rd_data_i),
        .rd_we_i(rd_we_i)
    );

    always_comb begin
        if (rd_we_i && (rs1_addr == rd_addr_i) && (rs1_addr != 0)) begin
            _o.rs1_data = rd_data_i;
        end else begin
            _o.rs1_data = rf_rs1_data;
        end
    end

    always_comb begin
        if (rd_we_i && (rs2_addr == rd_addr_i) && (rs2_addr != 0)) begin
            _o.rs2_data = rd_data_i;
        end else begin
            _o.rs2_data = rf_rs2_data;
        end
    end

endmodule
