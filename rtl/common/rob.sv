// https://www.youtube.com/watch?v=9yo3yhUijQs

module rob #(
    parameter int XLEN = 32,
    parameter int N_ENTRIES = 8
) (
    input logic clk,
    input logic reset_n,

    // Issue interface
    input  logic            issue_valid_i,
    input  logic [XLEN-1:0] pc_i,
    input  logic            rd_we_i,
    input  logic [4:0]      rd_addr_i,
    input  logic [XLEN-1:0] rd_data_i,
    input  logic            st_we_i,
    input  logic [XLEN-1:0] st_addr_i,
    input  logic [XLEN-1:0] st_data_i,
    output rob_id_t         rob_id_o,

    // Completed interface
    input  logic            completed_valid_i,
    input  rob_id_t         rob_id_i,

    // Interface with register file
    output logic            we_o,
    output logic [4:0]      rd_addr_o,
    output logic [XLEN-1:0] rd_data_o,
)
    // Define a type for reorder buffer
    typedef logic[$clog2(N_ENTRIES)-1:0] rob_id_t;

    typedef struct packed {
        logic               valid;
        logic [XLEN-1:0]    pc;

        logic               rd_valid;
        logic [4:0]         rd_addr;
        logic [XLEN-1:0]    rd_data;

        logic               st_valid;
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
    reg rob_entry_t [N_ENTRIES-1:0] entries;

    // Write to entries and control head and tail
    always @(posedge clk) begin
        if (!reset_n) begin
            head <= '0;
            tail <= '0;
            for (int i = 0; i < N_ENTRIES; ++i) begin
                entries[i].valid <= 0;
            end
        end else begin
            if (issue_valid_i) begin
                // Increase the tail pointer, and offer the new rob_id to the
                // newly issued instruction
            end else if (completed_valid_i) begin
                // Increase the head pointer, and drive the interface to write
                // the new state
            end
            // TODO: CAM for younger instructions to use my value
        end
    end

endmodule
