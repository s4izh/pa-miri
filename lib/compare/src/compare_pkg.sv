`ifndef COMPARE_PKG_
`define COMPARE_PKG_

package compare_pkg;

    typedef enum logic[1:0] {
        CMP_NOOP = 0,
        CMP_EQ = 1,
        CMP_LT = 2,
        CMP_GT = 3
    } compare_op_e;

endpackage

`endif
