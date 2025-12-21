module konata_tracer #(
    parameter int XLEN = 32,
    parameter string LOG_PREFIX = "konata_output"
)(
    input logic clk,
    input logic reset_n,
    input logic stall_i,

    // hooks
    input logic valid_f_i, // !noop
    input logic valid_d_i, // s_1f_q.valid
    input logic valid_e_i, // s_2d_q.valid
    input logic valid_m_i, // s_3e_q.valid
    input logic valid_w_i, // s_4m_q.valid

    // fetch info
    input logic [XLEN-1:0] fetch_pc_i,
    input logic [31:0]     fetch_ins_i
);

    // Serial id counter
    longint unsigned id_counter;

    // id_pipe[0] corresponds to Fetch
    // id_pipe[1] corresponds to Decode
    // id_pipe[2] corresponds to Execute
    // id_pipe[3] corresponds to Memory
    // id_pipe[4] corresponds to Writeback
    // id_pipe[5] is used to flag the cycle in which the ins was retired
    longint unsigned id_pipe[6];

    // Iterable stage names
    const string stage_names[5] = {"F","D","E","M","W"};

    // Iterable stage valids
    logic [4:0] stage_valids;
    assign stage_valids[0] = valid_f_i;
    assign stage_valids[1] = valid_d_i;
    assign stage_valids[2] = valid_e_i;
    assign stage_valids[3] = valid_m_i;
    assign stage_valids[4] = valid_w_i;

    // Init kanata format
    //   - Header
    //   - Current cycle
    initial begin
        $display("%s:Kanata\t0004", LOG_PREFIX);
        $display("%s:C=\t0", LOG_PREFIX);
    end

    // Main process (id_pipe[] control)
    always @(posedge clk) begin
        // Advance 1 cycle
        $display("%s:C\t1", LOG_PREFIX);
        if (!reset_n) begin
            id_pipe <= '{default:0};
            id_counter = 1;
        end else begin
            // Shift register
            if (!stall_i) begin
                id_pipe[5] <= (valid_w_i) ? id_pipe[4] : 0;
                id_pipe[4] <= (valid_m_i) ? id_pipe[3] : 0;
                id_pipe[3] <= (valid_e_i) ? id_pipe[2] : 0;
                id_pipe[2] <= (valid_d_i) ? id_pipe[1] : 0;
                id_pipe[1] <= (valid_f_i) ? id_pipe[0] : 0;
            end else begin
                id_pipe[5] <= (valid_w_i) ? id_pipe[4] : 0;
                id_pipe[4] <= (valid_m_i) ? id_pipe[3] : 0;
                id_pipe[3] <= (valid_e_i) ? id_pipe[2] : 0;
                id_pipe[2] <= 0;
            end
            // If not stalled, "issue" new instruction
            if (!stall_i) begin
                $display("%s:I\t%0d\t%0t\t%0d",
                    LOG_PREFIX, id_counter, fetch_pc_i, 0);
                $display("%s:L\t%0d\t%0d\t%s",
                    LOG_PREFIX, id_counter, 0, rv32_util_pkg::disasm_rv32i(fetch_ins_i));
                id_pipe[0] <= id_counter;
                id_counter++;
            end
        end
    end

    // Control instruction's stage and retire
    always @(posedge clk) begin
        if (reset_n) begin
            for (int i = 0; i < 5; ++i) begin
                if (id_pipe[i] != 0) begin
                    if (stage_valids[i])
                        $display(konata_stage(id_pipe[i], 0, stage_names[i]));
                    else
                        $display(konata_retire(id_pipe[i], 0, 1));
                end
            end

            if (id_pipe[5] != 0) $display(konata_retire(id_pipe[5], 0, 0));
        end
    end

    // Helpers for konata logs
    function konata_stage(longint id, int thread, string stage);
        $display("%s:S\t%0d\t%0d\t%s",
            LOG_PREFIX, id, thread, stage);
    endfunction

    function konata_retire(longint id, int retire_id, int retire_type);
            $display("%s:R\t%0d\t%0d\t%0d",
                LOG_PREFIX, id, retire_id, retire_type);
    endfunction

endmodule
