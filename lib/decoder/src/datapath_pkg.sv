package datapath_pkg;

    `define MUX_RA_WIDTH 1
    `define MUX_RA_PC `MUX_RA_WIDTH'b0
    `define MUX_RA_RA `MUX_RA_WIDTH'b1

    `define MUX_RB_WIDTH 1
    `define MUX_RB_IMMED `MUX_RB_WIDTH'b0
    `define MUX_RB_RB    `MUX_RB_WIDTH'b1

    // typedef enum logic {
    //     MUX_RA_PC = 0,
    //     MUX_RA_RA = 1
    // } mux_ra_e;
    //
    // typedef enum logic {
    //     MUX_RA_IMMED = 0,
    //     MUX_RA_RB    = 1
    // } mux_rb_e;

endpackage
