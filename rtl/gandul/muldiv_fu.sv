module muldiv_fu #(
    parameter int OP_DELAY = 5
) (
    input  logic clk,
    input  logic reset_n,
    input  signals_muldiv_op_t      _i,
    output signals_muldiv_results_t _o,
    input  logic noop_i,
    input  logic stall_i
);

    signals_muldiv_op_t pipeline[OP_DELAY];

    always @(posedge clk) begin
        if (~reset_n | noop_i) begin
            for (int i = 0; i < OP_DELAY; ++i) begin
                pipeline[i] <= '0;
            end
        end else if (~stall_i) begin
            for (int i = 1; i < OP_DELAY; ++i) begin
                pipeline[i] <= pipeline[i-1];
            end
            pipeline[i] <= _i;
        end
    end

    always_comb begin
        if (~reset_n | noop_i | stall_i) begin
            _o = '0;
        end else begin
            _o.valid = pipeline[OP_DELAY-1].valid;
            _o.robid = pipeline[OP_DELAY-1].robid;
            case(pipeline[OP_DELAY-1].op)
                MULDIV_OP_MUL: begin
                    _o.xcpt = 0;
                    _o.result = pipeline[OP_DELAY-1].rs1 * pipeline[OP_DELAY-1].rs2;
                end
                MULDIV_OP_MUL: begin
                    _o.xcpt = (pipeline[OP_DELAY-1].rs2 == 0);
                    if (_o.xcpt) begin
                        _o.result = '0;
                    end else begin
                        _o.result = pipeline[OP_DELAY-1].rs1 / pipeline[OP_DELAY-1].rs2;
                    end
                end
            endcase
        end
    end

endmodule
