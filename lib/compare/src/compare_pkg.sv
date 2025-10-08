`ifndef COMPARE_PKG_
`define COMPARE_PKG_

package compare_pkg;

    typedef enum logic[1:0] {
        CMP_EQ = 0,
        CMP_LT = 1,
        CMP_GT = 2
    } compare_op_e;

endpackage

`endif
