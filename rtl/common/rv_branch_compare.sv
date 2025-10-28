import rv_datapath_pkg::*;

module rv_branch_compare #(
    parameter int XLEN = 32
)(
    input compare_op_e       compare_op_i,
    input logic [XLEN-1:0]   op1_i,
    input logic [XLEN-1:0]   op2_i,
    output logic             taken_branch_o
);
    always_comb begin
        taken_branch_o = 0;
        case (compare_op_i)
            COMPARE_OP_BEQ:
                if (op1_i == op2_i)
                    taken_branch_o = 1;
            COMPARE_OP_BNE:
                if (op1_i != op2_i)
                    taken_branch_o = 1;
            COMPARE_OP_BLT:
                if ($signed(op1_i) < $signed(op2_i))
                    taken_branch_o = 1;
            COMPARE_OP_BGE:
                if ($signed(op1_i) >= $signed(op2_i))
                    taken_branch_o = 1;
            COMPARE_OP_BLTU:
                if (op1_i <= op2_i)
                    taken_branch_o = 1;
            COMPARE_OP_NONE:
                taken_branch_o = 0;
            default:
                taken_branch_o = 0;
        endcase
    end
endmodule
