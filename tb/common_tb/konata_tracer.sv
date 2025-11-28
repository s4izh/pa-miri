module konata_tracer #(
    parameter int XLEN = 32,
    parameter string LOG_PREFIX = "konata_output"
)(
    input logic clk,
    input logic reset_n,
    input logic stall_i,

    // HARDWARE HOOKS
    // we look at the VALID bits coming out of each pipeline register.
    // if the hardware says valid=1, we track it. If valid=0, it's a bubble.
    input logic valid_f_i, // !noop
    input logic valid_d_i, // s_1f_q.valid
    input logic valid_e_i, // s_2d_q.valid
    input logic valid_m_i, // s_3e_q.valid
    input logic valid_w_i, // s_4m_q.valid

    // we need the fetch info to describe the instruction
    input logic [XLEN-1:0] fetch_pc_i,
    input logic [31:0]     fetch_ins_i
);

    longint unsigned id_counter = 1;

    // a simple shift register to carry IDs down the pipeline
    // id_pipe[0] corresponds to Fetch
    // id_pipe[1] corresponds to Decode
    // id_pipe[2] corresponds to Execute
    // id_pipe[3] corresponds to Memory
    // id_pipe[4] corresponds to Writeback
    longint unsigned id_pipe [4:0];

    // track the previous valid instruction to calculate retirement latency
    longint unsigned last_retired_id;

    always @(posedge clk) begin
        if (!reset_n) begin
            id_pipe <= '{default:0};
            id_counter <= 1;
        end else if (!stall_i) begin
            // 1. Shift the IDs down the pipe (Synchronous with HW pipeline regs)
            id_pipe[4] <= id_pipe[3];
            id_pipe[3] <= id_pipe[2];
            id_pipe[2] <= id_pipe[1];
            id_pipe[1] <= id_pipe[0];

            // 2. Insert new ID at Fetch if valid
            // If the processor is flushing (valid_f_i is low), we insert a 0 (bubble)
            if (valid_f_i) begin
                id_pipe[0] <= id_counter;
                
                // Log the creation of this instruction immediately
                // fetch : time : pc : global_id : 0 : asm
                $display("%s:O3PipeView:fetch:%0t:0x%h:%0d:0:DASM(%h)", 
                         LOG_PREFIX, $time, fetch_pc_i, id_counter, fetch_ins_i);
                
                id_counter++;
            end else begin
                id_pipe[0] <= 0; // Bubble
            end
        end
    end

    // 3. Log Stage Transitions
    // We look at the ID that IS ENTERING the stage on this clock edge.
    // Since we use non-blocking assignments above, we check the OLD value of the previous stage.
    always @(posedge clk) begin
        if (reset_n && !stall_i) begin
            
            // ID moving from Fetch (pipe[0]) -> Decode (pipe[1])
            // We check valid_d_i to see if the hardware accepted it
            if (id_pipe[0] != 0) 
                $display("%s:O3PipeView:decode:%0t:%0d", LOG_PREFIX, $time, id_pipe[0]);

            // ID moving from Decode (pipe[1]) -> Execute (pipe[2])
            if (id_pipe[1] != 0 && valid_e_i) 
                $display("%s:O3PipeView:issue:%0t:%0d", LOG_PREFIX, $time, id_pipe[1]);

            // ID moving from Execute (pipe[2]) -> Memory (pipe[3])
            if (id_pipe[2] != 0 && valid_m_i) 
                $display("%s:O3PipeView:complete:%0t:%0d", LOG_PREFIX, $time, id_pipe[2]);

            // ID moving from Memory (pipe[3]) -> Writeback (pipe[4]) -> Retire
            if (id_pipe[3] != 0 && valid_w_i) 
                $display("%s:O3PipeView:retire:%0t:store:%0t:%0d", LOG_PREFIX, $time, $time, id_pipe[3]);
        end
    end

endmodule
