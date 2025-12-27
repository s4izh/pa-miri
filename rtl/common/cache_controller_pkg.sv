`ifndef _CACHE_CONTROLLER_PKG_
`define _CACHE_CONTROLLER_PKG_

package cache_controller_pkg;

    typedef enum logic[1:0] {
        MEMOP_WIDTH_8,
        MEMOP_WIDTH_16,
        MEMOP_WIDTH_32,
        MEMOP_WIDTH_INVALID
    } memop_width_e;

endpackage

`endif
