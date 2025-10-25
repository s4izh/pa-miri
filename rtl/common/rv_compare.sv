import datapath_pkg::*;

module rv_branch_compare #(
    parameter int XLEN = 32
)(
    input compare_op_e       compare_op_i,
    input logic [XLEN-1:0]   rs1_data_i,
    input logic [XLEN-1:0]   rs2_data_i,
    output logic             taken_branch_o
);
    always_comb begin
        taken_branch_o = 0;
        case (compare_op_i)
            COMPARE_OP_BEQ:
                if (rs1_data_i == rs2_data_i)
                    taken_branch_o = 1;
            COMPARE_OP_BNE:
                if (rs1_data_i != rs2_data_i)
                    taken_branch_o = 1;
            COMPARE_OP_BLT:
                if ($signed(rs1_data_i) < $signed(rs2_data_i))
                    taken_branch_o = 1;
            COMPARE_OP_BGE:
                if ($signed(rs1_data_i) >= $signed(rs2_data_i))
                    taken_branch_o = 1;
            COMPARE_OP_BLTU:
                if (rs1_data_i <= rs2_data_i)
                    taken_branch_o = 1;
            COMPARE_OP_NONE:
                taken_branch_o = 0;
        endcase
    end
endmodule
