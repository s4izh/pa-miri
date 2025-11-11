module decoupling_reg#(
    parameter type regtype_t = int
)(
    input clk,
    input reset_n,
    input stall_i,
    input  regtype_t d_i,
    output regtype_t q_o
);

    regtype_t r_reg;

    always_ff @(posedge clk) begin
        if (reset_n) r_reg <= 0;
        else if (!stall_i) begin
            r_reg <= d_i;
        end
    end

    assign q_o = r_reg;

endmodule
