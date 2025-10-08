package datapath_pkg;

    typedef enum logic[1:0] {
        MUX_RA_PC = 0,
        MUX_RA_RA = 1,
        MUX_RA_0  = 2
    } mux_ra_e;

    typedef enum logic {
        MUX_RB_IMMED = 0,
        MUX_RB_RB    = 1
    } mux_rb_e;

endpackage
