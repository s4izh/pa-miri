// Simple Processor Module
// This is a minimal SystemVerilog processor for development environment testing

`timescale 1ns/1ps

module simple_processor (
    input  logic       clk,
    input  logic       reset_n,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic       valid_out
);

    // Internal registers
    logic [7:0] accumulator;
    logic [1:0] state;
    
    // State definitions
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        LOAD  = 2'b01,
        PROC  = 2'b10,
        OUT   = 2'b11
    } state_t;
    
    state_t current_state, next_state;
    
    // State register
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            current_state <= IDLE;
            accumulator <= 8'h00;
        end else begin
            current_state <= next_state;
            if (current_state == LOAD) begin
                accumulator <= data_in;
            end else if (current_state == PROC) begin
                accumulator <= accumulator + 8'h01; // Simple increment operation
            end
        end
    end
    
    // Next state logic
    always_comb begin
        case (current_state)
            IDLE: next_state = LOAD;
            LOAD: next_state = PROC;
            PROC: next_state = OUT;
            OUT:  next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Output logic
    assign data_out = accumulator;
    assign valid_out = (current_state == OUT);

endmodule