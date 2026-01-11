module muldiv_fu #(
    parameter int OP_DELAY = 6
) (
    input  logic                clk,
    input  logic                reset_n,
    input  signals_muldiv_in_t  _i,
    output signals_muldiv_out_t _o,
    input  logic                noop_i,
    input  logic                stall_i
);

    signals_muldiv_in_t pipeline[OP_DELAY];
    signals_muldiv_in_t plast;
    assign plast = pipeline[OP_DELAY-1];

    always @(posedge clk) begin
        if (~reset_n | noop_i) begin
            for (int i = 0; i < OP_DELAY; ++i) begin
                pipeline[i] <= '0;
            end
        end else if (~stall_i) begin
            pipeline[0] <= _i;
            for (int i = 1; i < OP_DELAY; ++i) begin
                pipeline[i] <= pipeline[i-1];
            end
        end
    end

    always_comb begin
        logic   signed [63:0] s_result;
        logic unsigned [63:0] u_result;

        s_result = '0;
        u_result = '0;

        if (~reset_n | noop_i | stall_i) begin
            _o = '0;
        end else begin
            _o.valid = plast.valid;
            _o.robid = plast.robid;
            case(pipeline[OP_DELAY-1].op)
                MULDIV_OP_MUL: begin
                    // lowerh of signed*signed
                    _o.xcpt   = 0;
                    s_result  = $signed(plast.rs1) * $signed(plast.rs2);
                    _o.result = s_result[31:0];
                end
                MULDIV_OP_MULH: begin
                    // upperh of signed*signed
                    _o.xcpt   = 0;
                    s_result  = $signed(plast.rs1) * $signed(plast.rs2);
                    _o.result = s_result[63:32];
                end
                MULDIV_OP_MULHSU: begin
                    // upperh of signed*unsigned
                    _o.xcpt   = 0;
                    s_result  = $signed(plast.rs1) * plast.rs2;
                    _o.result = s_result[63:32];
                end
                MULDIV_OP_MULHU: begin
                    // upperh of unsigned*unsigned
                    _o.xcpt   = 0;
                    u_result  = plast.rs1 * plast.rs2;
                    _o.result = u_result[63:32];
                end
                MULDIV_OP_DIV: begin
                    _o.xcpt = plast.rs2 == 32'h0;
                    if (_o.xcpt) begin
                        _o.result = '1; // -1
                    end else begin
                        _o.result = $signed(plast.rs1) / $signed(plast.rs2);
                    end
                end
                MULDIV_OP_DIVU: begin
                    _o.xcpt = plast.rs2 == 32'h0;
                    if (_o.xcpt) begin
                        _o.result = '1; // -1
                    end else begin
                        _o.result = plast.rs1 / plast.rs2;
                    end
                end
                MULDIV_OP_REM: begin
                    _o.xcpt = plast.rs2 == 32'h0;
                    if (_o.xcpt) begin
                        _o.result = plast.rs1;
                    end else begin
                        _o.result = $signed(plast.rs1) % $signed(plast.rs2);
                    end
                end
                MULDIV_OP_REMU: begin
                    _o.xcpt = plast.rs2 == 32'h0;
                    if (_o.xcpt) begin
                        _o.result = plast.rs1;
                    end else begin
                        _o.result = plast.rs1 % plast.rs2;
                    end
                end
            endcase
        end
    end

endmodule
