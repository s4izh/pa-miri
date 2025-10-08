import datapath_pkg::*;
import compare_pkg::*;

module pa_cpu_mini1# (
    parameter int XLEN = 32,
    parameter int IALEN = 12,
    parameter int DALEN = 12,
    parameter int NREG = 32
)(
    input  logic clk,
    input  logic reset_n,

    output logic[IALEN-1:0] imem_addr_o,
    input  logic[XLEN-1:0]  imem_data_i,

    output logic[DALEN-1:0] dmem_addr_o,
    output logic[XLEN-1:0]  dmem_data_o,
    output logic            dmem_we_o,
    input  logic[XLEN-1:0]  dmem_data_i
);

    localparam int RALEN = $clog2(NREG);
    // localparam int IMEM_SIZE = 2 ** IALEN;
    // localparam int DMEM_SIZE = 2 ** DALEN;

    logic [XLEN-1:0] ra_data, rb_data, rd_data;
    logic rd_we;
    logic [RALEN-1:0] ra_addr, rb_addr, rd_addr;

    logic [IALEN-1:0] pc;

    logic immed;
    mux_ra_e ra_m;
    mux_rb_e rb_m;
    mux_pc_e pc_m;
    logic is_ld, is_wb, is_st;

    logic [XLEN-1:0] add_op_1, add_op_2, add_op_result;

    assign imem_addr_o = pc;
    assign add_op_result = add_op_1 + add_op_2;

    assign pc_m = MUX_PC_MAS_UNO;

    // PC
    always @(posedge clk) begin
        if (!reset_n) begin
            pc <= 0;
        end else begin
            case (pc_m)
                MUX_PC_MAS_UNO:
                    pc <= pc + IALEN'(1);
                MUX_PC_BRANCH:
                    // TODO
                    pc <= add_op_result;
            endcase
        end
    end

    always_comb begin
        case (ra_m)
            MUX_RA_PC:
                add_op_1 = pc;
            MUX_RA_RA:
                add_op_1 = ra_data;
            MUX_RA_0:
                add_op_1 = XLEN'(0);
        endcase
    end

    always_comb begin
        case (rb_m)
            MUX_RB_IMMED:
                add_op_2 = immed;
            MUX_RB_RB:
                add_op_2 = ra_data;
        endcase
    end

    regfile #(
        .XLEN(XLEN),
        .NREG(NREG)
    ) regs (
        .clk,
        .reset_n,

        .ra_addr_i(ra_addr),
        .ra_data_o(ra_data),

        .rb_addr_i(rb_addr),
        .rb_data_o(rb_data),

        .rd_addr_i(rd_addr),
        .rd_data_i(rd_data),
        .rd_we_i(rd_we)
    );

    decoder #(
        .XLEN(XLEN),
        .INS_WIDTH(XLEN),
        .NREG(NREG)
    ) dec (
        .ins_i(imem_data_i),
        .immed_o(immed),
        .ra_o(ra_addr),
        .rb_o(rb_addr),
        .rd_o(rd_addr),
        .mux_ra_o(ra_m),
        .mux_rb_o(rb_m),
        .is_ld_o(is_ld),
        .is_wb_o(is_wb),
        .is_st_o(is_st)
    );

    compare #(
        .XLEN(XLEN)
    ) cmp (
        .op1_i(ra_data),
        .op2_i(rb_data)
        // .op_i()
    );
endmodule
