`ifndef COMPARE_M_
`define COMPARE_M_

import compare_pkg::*;

module compare #(
    parameter int XLEN = 32
)(
    input logic[XLEN-1:0] op1_i,
    input logic[XLEN-1:0] op2_i,
    input compare_op_e op_i,
    output logic result_o
);
    always_comb begin
        case (op_i)
            CMP_EQ:
                result_o = (op1_i == op2_i) ? 1 : 0;
            CMP_LT:
                result_o = (op1_i < op2_i) ? 1 : 0;
            CMP_GT:
                result_o = (op1_i > op2_i) ? 1 : 0;
        endcase
    end
endmodule

`endif
