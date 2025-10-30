`ifndef _SIGN_EXTENDER_M_
`define _SIGN_EXTENDER_M_

import memory_controller_pkg::*;

module sign_extender #(
    parameter int XLEN = 32
)(
    input  logic [XLEN-1:0]   data_i,
    input  memop_width_e      width_i,

    output logic [XLEN-1:0]   data_signed_o
);
    logic [XLEN-1:0] byte_signed;
    logic [XLEN-1:0] half_signed;

    assign byte_signed   = {{XLEN-8{data_i[7]}}, data_i[7:0]};
    assign half_signed   = {{XLEN-16{data_i[15]}}, data_i[15:0]};

    always_comb begin
        case (width_i)
            MEMOP_WIDTH_8: begin
                data_signed_o   = byte_signed;
            end
            MEMOP_WIDTH_16: begin
                data_signed_o   = half_signed;
            end
            default: begin
                data_signed_o   = data_i;
            end
        endcase
    end

endmodule

`endif
