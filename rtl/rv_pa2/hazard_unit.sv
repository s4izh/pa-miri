module hazard_unit (
    input  logic jump_or_branch_3e_i,
    input  logic data_hazard_i,
    output logic noop_o,
    output logic stall_o
);
    assign noop_o  = jump_or_branch_3e_i;
    assign stall_o = data_hazard_i;
endmodule
