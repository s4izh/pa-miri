module fwd_unit #(
    parameter int XLEN = 32
) (
    input  logic [4:0] rs1_2d_i,
    input  logic [4:0] rs2_2d_i,
    input  logic       rs1_valid_2d_i,
    input  logic       rs2_valid_2d_i,
    input  logic       is_st_2d_i,

    // stage 3e inputs
    input  logic [4:0]      rd_3e_i,
    input  logic            rd_is_wb_3e_i,
    input  logic            is_ld_3e_i,
    input  logic [XLEN-1:0] data_3e_i,

    // stage 4m inputs
    input  logic [4:0]      rd_4m_i,
    input  logic            rd_is_wb_4m_i,
    input  logic [XLEN-1:0] data_4m_i,

    // stage 5w inputs
    input  logic [4:0]      rd_5w_i,
    input  logic            rd_is_wb_5w_i,
    input  logic [XLEN-1:0] data_5w_i,

    // rob inputs
    input  logic            rob_cam_rs1_valid_i,
    input  logic [XLEN-1:0] rob_cam_rs1_data_i,
    input  logic            rob_cam_rs2_valid_i,
    input  logic [XLEN-1:0] rob_cam_rs2_data_i,

    output logic            bypass_rs1_2d_sel_o,
    output logic            bypass_rs2_2d_sel_o,
    output logic [XLEN-1:0] bypass_rs1_2d_data_o,
    output logic [XLEN-1:0] bypass_rs2_2d_data_o,
    output logic            bypass_4m_3e_sel_o,
    output logic            fwd_unit_hazard_o
);

    logic rd_3e_not_zero, rd_4m_not_zero, rd_5w_not_zero;
    logic hazard_ld;

    assign rd_3e_not_zero = (rd_3e_i != '0);
    assign rd_4m_not_zero = (rd_4m_i != '0);
    assign rd_5w_not_zero = (rd_5w_i != '0);

    always_comb begin
        hazard_ld = 1'b0;
        bypass_4m_3e_sel_o = 1'b0;
        if (is_ld_3e_i && rd_3e_not_zero) begin
            if (rs1_valid_2d_i && (rs1_2d_i == rd_3e_i)) begin
                hazard_ld = 1'b1;
            end
            if (rs2_valid_2d_i && (rs2_2d_i == rd_3e_i)) begin
                if (is_st_2d_i)
                    bypass_4m_3e_sel_o = 1'b1;
                else
                    hazard_ld = 1'b1;
            end
        end
    end

    always_comb begin
        bypass_rs1_2d_sel_o  =  0;
        bypass_rs1_2d_data_o = '0;

        if ((rs1_2d_i == rd_3e_i) && rd_3e_not_zero && rs1_valid_2d_i && rd_is_wb_3e_i) begin
            bypass_rs1_2d_sel_o  = 1;
            bypass_rs1_2d_data_o = data_3e_i;
        end else if ((rs1_2d_i == rd_4m_i) && rd_4m_not_zero && rs1_valid_2d_i && rd_is_wb_4m_i) begin
            bypass_rs1_2d_sel_o  = 1;
            bypass_rs1_2d_data_o = data_4m_i;
        end else if ((rs1_2d_i == rd_5w_i) && rd_5w_not_zero && rs1_valid_2d_i && rd_is_wb_5w_i) begin
            bypass_rs1_2d_sel_o  = 1;
            bypass_rs1_2d_data_o = data_5w_i;
        end else if (rob_cam_rs1_valid_i) begin
            bypass_rs1_2d_sel_o  = 1;
            bypass_rs1_2d_data_o = rob_cam_rs1_data_i;
        end
    end

    always_comb begin
        bypass_rs2_2d_sel_o  =  0;
        bypass_rs2_2d_data_o = '0;

        if ((rs2_2d_i == rd_3e_i) && rd_3e_not_zero && rs2_valid_2d_i && rd_is_wb_3e_i) begin
            bypass_rs2_2d_sel_o  = 1;
            bypass_rs2_2d_data_o = data_3e_i;
        end else if ((rs2_2d_i == rd_4m_i) && rd_4m_not_zero && rs2_valid_2d_i && rd_is_wb_4m_i) begin
            bypass_rs2_2d_sel_o  = 1;
            bypass_rs2_2d_data_o = data_4m_i;
        end else if ((rs2_2d_i == rd_5w_i) && rd_5w_not_zero && rs2_valid_2d_i && rd_is_wb_5w_i) begin
            bypass_rs2_2d_sel_o  = 1;
            bypass_rs2_2d_data_o = data_5w_i;
        end else if (rob_cam_rs2_valid_i) begin
            bypass_rs2_2d_sel_o  = 1;
            bypass_rs2_2d_data_o = rob_cam_rs2_data_i;
        end
    end

    assign fwd_unit_hazard_o = hazard_ld;


endmodule
