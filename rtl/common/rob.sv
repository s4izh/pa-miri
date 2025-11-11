// https://www.youtube.com/watch?v=9yo3yhUijQs

module rob #(
    parameter int XLEN = 32,
    parameter int N_ENTRIES = 8,

    parameter type rob_id_t = logic[$clog2(N_ENTRIES)-1:0]
) (
    input logic clk,
    input logic reset_n,

    // Issue interface
    input  logic            issue_valid_i,
    input  logic [XLEN-1:0] issue_pc_i,
    input  logic            issue_rd_we_i,
    input  logic [4:0]      issue_rd_addr_i,
    input  logic            issue_st_we_i,
    input  logic [XLEN-1:0] issue_st_data_i,
    output rob_id_t         issue_robid_o,

    // writable at a latter time
    // input  logic [XLEN-1:0] complete_st_addr_i,
    // input  logic            complete_st_addr_i,
    // input  logic            complete_xcpt_i,
    // input  rob_id_t         complete_xcpt_robid_i,

    // Complete interface
    input  logic            complete_valid_i,
    input  rob_id_t         complete_rob_id_i,
    input  logic [XLEN-1:0] complete_rd_data_i,

    // Commit interface
    output logic            commit_we_o,
    output logic [4:0]      commit_rd_addr_o,
    output logic [XLEN-1:0] commit_rd_data_o
);
    // Define a type for reorder buffer

    typedef struct packed {
        logic               valid;
        logic [XLEN-1:0]    pc;

        logic               rd_we;
        logic [4:0]         rd_addr;
        logic               rd_data_valid;
        logic [XLEN-1:0]    rd_data;

        logic               st_we;
        logic               st_addr_valid;
        logic [XLEN-1:0]    st_addr;
        logic [XLEN-1:0]    st_data;
        // valid bits for reg/data + control bits
        logic               xcpt;
    } rob_entry_t;

    // Tail points to the youngest entry
    // Head points to the oldest entry
    // Therefore, instructions are instroduced through the tail,
    // and completed through the head
    //      ........
    //    | rob_id 3 | <- head
    //    | rob_id 4 |
    //    | rob_id 5 |
    //    | rob_id 6 |
    //    | rob_id 7 | <- tail
    //      ........
    rob_id_t tail, head;
    rob_entry_t [N_ENTRIES-1:0] entries;

    // Write to entries and control head and tail
    always @(posedge clk) begin
        if (!reset_n) begin
            head <= '0;
            tail <= '0;
        end else begin
            if (issue_valid_i) begin
                // Increase the tail pointer, and offer the new rob_id to the
                // newly issued instruction
                entries[tail].pc            <= issue_pc_i;
                entries[tail].rd_we         <= issue_rd_we_i;
                entries[tail].rd_addr       <= issue_rd_addr_i;
                entries[tail].rd_data_valid <= 0;
                entries[tail].st_we         <= issue_st_we_i;
                entries[tail].xcpt          <= 0;
                issue_robid_o               <= tail;
                tail                        <= tail + 1;
            end

            if (complete_valid_i) begin
                // Find the entry completed and mark it as so in the
                // corresponding rob entry
                // TOCHECK: complete_rob_id_i should be between tail and head
                entries[complete_rob_id_i].rd_data_valid    <= 1;
                entries[complete_rob_id_i].rd_data          <= complete_rd_data_i;
            end

            if (entries[head].rd_data_valid) begin
                // An instruction has finished. We commit and write to the RF
                commit_we_o         <= entries[head].rd_we;
                commit_rd_addr_o    <= entries[head].rd_addr;
                commit_rd_data_o    <= entries[head].rd_data;
                entries[head].valid <= 0;
                head                <= head + 1;
            end
            // TODO: CAM lookup for younger instructions to use my value
        end
    end


endmodule
