module valid_delayer #(
    parameter int N = 5
) (
    input  logic clk,
    input  logic valid_i,
    output logic valid_o
);
    logic [N-1:0] valid_queue;
    always @(posedge clk) begin
        // Propagate
        for (int i = 1; i < N; ++i) begin
            valid_queue[i] <= valid_queue[i-1];
        end
        // Insert conditionally at the bottom
        if (!(|valid_queue)) valid_queue[0] <= valid_i;
        else                 valid_queue[0] <= 0;
    end
    assign valid_o = valid_queue[N-1];
endmodule
