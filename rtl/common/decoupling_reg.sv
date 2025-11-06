module decoupling_reg#(
    parameter type regtype_t = int
)(
    input clk_i,
    input rst_i,
    input stall_i,
    input  regtype_t d_i,
    output regtype_t q_o
);

    regtype_t r_reg;

    always_ff @(posedge clk_i or posedge rst_i) begin
        if (!stall_i) begin
            if (rst_i) r_reg <= 0;
            else r_reg <= d_i;
        end
    end

    assign q_o = r_reg;

endmodule
