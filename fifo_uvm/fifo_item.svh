typedef enum logic { FIFO_WRITE, FIFO_READ } fifo_op_e;

class fifo_item extends uvm_sequence_item;
    `uvm_object_utils(fifo_item)

    rand fifo_op_e   op;
    rand logic [7:0] data;

    function new(string name = "fifo_item");
        super.new(name);
    endfunction
endclass
