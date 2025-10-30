`ifndef _ALU_M_
`define _ALU_M_

import alu_pkg::*;

module alu#(
    parameter int XLEN = 32
)(
    input logic [XLEN-1:0] op1_i,
    input logic [XLEN-1:0] op2_i,
    input logic [3:0] alu_op_i,
    output logic [XLEN-1:0] result_o
);
    localparam XLEN_LOG2 = $clog2(XLEN);
    always_comb begin
        case (alu_op_i)
            ALU_ADD:  result_o = op1_i + op2_i;
            ALU_SUB:  result_o = op1_i - op2_i;
            ALU_AND:  result_o = op1_i & op2_i;
            ALU_OR:   result_o = op1_i | op2_i;
            ALU_XOR:  result_o = op1_i ^ op2_i;
            ALU_SLT:  result_o = ($signed(op1_i) < $signed(op2_i)) ? 1 : 0;
            ALU_SLTU: result_o = (op1_i < op2_i) ? 1 : 0;
            ALU_SLL:  result_o = op1_i << op2_i[XLEN_LOG2-1:0];
            ALU_SRL:  result_o = op1_i >> op2_i[XLEN_LOG2-1:0];
            ALU_SRA: begin
                if (op2_i == XLEN) begin
                    result_o = {XLEN{op1_i[XLEN-1]}};
                end else begin
                    result_o = (op1_i >> op2_i[4:0]) | ({XLEN{op1_i[XLEN-1]}} << (XLEN - op2_i[XLEN_LOG2-1:0]));
                end
            end
            default:  result_o = '0;
        endcase
    end
endmodule

`endif
