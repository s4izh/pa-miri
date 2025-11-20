module hazard_unit (
    input  logic [4:0] rs1_2d_i,
    input  logic [4:0] rs2_2d_i,
    input  logic       rs1_valid_2d_i,
    input  logic       rs2_valid_2d_i,
    input  logic [4:0] rd_3e_i,
    input  logic [4:0] rd_4m_i,
    input  logic [4:0] rd_5w_i,
    input  logic       rd_is_wb_3e_i,
    input  logic       rd_is_wb_4m_i,
    input  logic       rd_is_wb_5w_i,

    input  logic jump_or_branch_3e_i,

    output logic noop_o,
    output logic stall_o
);

    logic rd_3e_not_zero, rd_4m_not_zero, rd_5w_not_zero;

    assign rd_3e_not_zero = (rd_3e_i != '0);
    assign rd_4m_not_zero = (rd_4m_i != '0);
    assign rd_5w_not_zero = (rd_5w_i != '0);

    assign noop_o = jump_or_branch_3e_i;
    assign stall_o = (
        ((rs1_2d_i == rd_3e_i) && rd_3e_not_zero && rs1_valid_2d_i && rd_is_wb_3e_i) ||
        ((rs1_2d_i == rd_4m_i) && rd_4m_not_zero && rs1_valid_2d_i && rd_is_wb_4m_i) ||
        ((rs1_2d_i == rd_5w_i) && rd_5w_not_zero && rs1_valid_2d_i && rd_is_wb_5w_i) ||

        ((rs2_2d_i == rd_3e_i) && rd_3e_not_zero && rs2_valid_2d_i && rd_is_wb_3e_i) ||
        ((rs2_2d_i == rd_4m_i) && rd_4m_not_zero && rs2_valid_2d_i && rd_is_wb_4m_i) ||
        ((rs2_2d_i == rd_5w_i) && rd_5w_not_zero && rs2_valid_2d_i && rd_is_wb_5w_i)
    ) ? 1 : 0;

endmodule
