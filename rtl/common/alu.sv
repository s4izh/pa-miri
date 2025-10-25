`ifndef _ALU_M_
`define _ALU_M_

module alu#(
    parameter int XLEN = 32,
)(
    input logic [XLEN-1:0] op1_i,
    input logic [XLEN-1:0] op2_i,
    input logic [3:0] alu_op_i,
    output logic [XLEN-1:0] result_o
);
    always_comb begin
        case (alu_op_i)
            ALU_ADD:  result_o = op1_i + op2_i;
            ALU_SUB:  result_o = op1_i - op2_i;
            ALU_AND:  result_o = op1_i & op2_i;
            ALU_OR:   result_o = op1_i | op2_i;
            ALU_XOR:  result_o = op1_i ^ op2_i;
            ALU_SLT:  result_o = ($signed(op1_i) < $signed(op2_i)) ? 1 : 0;
            ALU_SLTU: result_o = (op1_i < op2_i) ? 1 : 0;
            ALU_SLL:  result_o = op1_i << op2_i[4:0];
            ALU_SRL:  result_o = op1_i >> op2_i[4:0];
            ALU_SRA:  result_o = $signed(op1_i) >>> op2_i[4:0];
            default:  result_o = '0;
        endcase
    end
endmodule

`endif
