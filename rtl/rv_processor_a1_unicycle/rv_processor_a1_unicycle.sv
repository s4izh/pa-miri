import rv_datapath_pkg::*;
import memory_controller_pkg::*;
import alu_pkg::*;
import rv_isa_pkg::*;

module rv_processor_a1_unicycle# (
    parameter int XLEN = 32
)(
    input  logic clk,
    input  logic reset_n,

    output logic[XLEN-1:0]  imem_addr_o,
    input  logic[XLEN-1:0]  imem_data_i,
    input  trap_t           imem_trap_i,

    output memop_width_e    dmem_width_o,
    output logic            dmem_memop_valid_o,
    output logic[XLEN-1:0]  dmem_addr_o,
    output logic[XLEN-1:0]  dmem_data_o,
    output logic            dmem_we_o,
    input  logic[XLEN-1:0]  dmem_data_i,
    input  trap_t           dmem_trap_i
);

    localparam int RALEN = $clog2(32);

    logic [XLEN-1:0] rs1_data, rs2_data, rd_data;
    logic [RALEN-1:0] rs1_addr, rs2_addr, rd_addr;

    compare_op_e compare_op;
    alu_op_e alu_op;

    logic [XLEN-1:0] pc;

    logic [XLEN-1:0] immed;
    mux_alu_op1_sel_e alu_op1_sel;
    mux_alu_op2_sel_e alu_op2_sel;
    mux_pc_sel_e pc_sel;
    mux_wb_sel_e wb_sel;

    logic illegal_ins, ld_unsigned, is_ld, is_wb, is_st, taken_branch;
    memop_width_e memop_width;

    logic [XLEN-1:0] alu_op1, alu_op2, alu_result;
    logic trap_valid;


    // local assigns
    assign trap_valid = imem_trap_i.valid | dmem_trap_i.valid;

    // external interface
    assign imem_addr_o = pc;
    assign dmem_addr_o = alu_result;
    assign dmem_data_o = rs2_data;
    assign dmem_we_o = is_st;
    assign dmem_width_o = memop_width;
    assign dmem_memop_valid_o = is_ld || is_st;

    // PC
    always @(posedge clk) begin
        if (!reset_n) begin
            pc <= 0'h1000;
        end else begin
            if (trap_valid) begin
                pc <= 0'h2000;
            end else begin
                case (pc_sel)
                    MUX_PC_NEXT:
                        pc <= pc + 4;
                    MUX_PC_BRANCH:
                        if (taken_branch)
                            pc <= alu_result;
                        else
                            pc <= pc + 4;
                    MUX_PC_JAL:
                        pc <= alu_result;
                    MUX_PC_JALR:
                        pc <= {alu_result[31:1], 1'b0};
                endcase
            end
        end
    end

    always_comb begin
        case(alu_op1_sel)
            MUX_ALU_OP1_RS1:
                alu_op1 = rs1_data;
            MUX_ALU_OP1_PC:
                alu_op1 = pc;
        endcase
    end

    always_comb begin
        case(alu_op2_sel)
            MUX_ALU_OP2_RS2:
                alu_op2 = rs2_data;
            MUX_ALU_OP2_IMM:
                alu_op2 = immed;
        endcase
    end

    always_comb begin
        case (wb_sel)
            MUX_WB_ALU:
                rd_data = alu_result;
            MUX_WB_MEM:
                rd_data = dmem_data_i;
            MUX_WB_PC_NEXT:
                rd_data = pc + 4;
        endcase
    end


    rv_regfile #(
        .XLEN(XLEN)
    ) regs_inst (
        .clk,
        .reset_n,

        .rs1_addr_i(rs1_addr),
        .rs1_data_o(rs1_data),

        .rs2_addr_i(rs2_addr),
        .rs2_data_o(rs2_data),

        .rd_addr_i(rd_addr),
        .rd_data_i(rd_data),
        .rd_we_i(is_wb)
    );

    rv_decoder #(
        .XLEN(XLEN)
    ) dec_inst (
        .ins_i(imem_data_i),

        .alu_op_o(alu_op),
        .alu_op1_sel_o(alu_op1_sel),
        .alu_op2_sel_o(alu_op2_sel),
        .wb_sel_o(wb_sel),

        .pc_sel_o(pc_sel),
        .illegal_ins_o(illegal_ins),

        .is_wb_o(is_wb),
        .is_ld_o(is_ld),
        .is_st_o(is_st),

        .rs1_addr_o(rs1_addr),
        .rs2_addr_o(rs2_addr),
        .rd_addr_o(rd_addr),
        .immed_o(immed),

        .compare_op_o(compare_op),
        .memop_width_o(memop_width),
        .ld_unsigned_o(ld_unsigned)
    );

    alu #(
        .XLEN(XLEN)
    ) alu_inst (
        .op1_i(alu_op1),
        .op2_i(alu_op2),
        .alu_op_i(alu_op),
        .result_o(alu_result)
    );

    rv_branch_compare #(
        .XLEN(XLEN)
    ) cmp_inst (
        .compare_op_i(compare_op),
        .op1_i(rs1_data),
        .op2_i(rs2_data),
        .taken_branch_o(taken_branch)
    );
endmodule

