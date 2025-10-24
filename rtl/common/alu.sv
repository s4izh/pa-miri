`ifndef _ALU_M_
`define _ALU_M_

module alu#(
    parameter int XLEN = 32,
)(
    input logic [XLEN-1:0] rs1_data_i,
    input logic [XLEN-1:0] rs2_data_i,
    input logic [3:0] alu_op_i,
    output logic [XLEN-1:0] alu_result_o
);
    always_comb begin
        case (alu_op_i)
            ALU_ADD:  alu_result_o = rs1_data_i + rs2_data_i;
            ALU_SUB:  alu_result_o = rs1_data_i - rs2_data_i;
            ALU_AND:  alu_result_o = rs1_data_i & rs2_data_i;
            ALU_OR:   alu_result_o = rs1_data_i | rs2_data_i;
            ALU_XOR:  alu_result_o = rs1_data_i ^ rs2_data_i;
            ALU_SLT:  alu_result_o = ($signed(rs1_data_i) < $signed(rs2_data_i)) ? 1 : 0;
            ALU_SLTU: alu_result_o = (rs1_data_i < rs2_data_i) ? 1 : 0;
            ALU_SLL:  alu_result_o = rs1_data_i << rs2_data_i[4:0];
            ALU_SRL:  alu_result_o = rs1_data_i >> rs2_data_i[4:0];
            ALU_SRA:  alu_result_o = $signed(rs1_data_i) >>> rs2_data_i[4:0];
            default:  alu_result_o = '0;
        endcase
    end
endmodule

`endif
