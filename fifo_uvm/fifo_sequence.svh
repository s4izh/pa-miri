class fifo_write_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_write_seq)

    int unsigned n = 4;

    function new(string name = "fifo_write_seq");
        super.new(name);
    endfunction

    task body();
        fifo_item item;
        for (int i = 0; i < n; i++) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.op   = FIFO_WRITE;
            item.data = 8'(i + 1);
            finish_item(item);
        end
    endtask
endclass

class fifo_read_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_read_seq)

    int unsigned n = 4;

    function new(string name = "fifo_read_seq");
        super.new(name);
    endfunction

    task body();
        fifo_item item;
        for (int i = 0; i < n; i++) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.op = FIFO_READ;
            finish_item(item);
        end
    endtask
endclass

// Attempt DEPTH+1 writes (the last one is silently dropped -- FIFO is full),
// then drain the DEPTH valid entries.
class fifo_overflow_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_overflow_seq)

    int unsigned depth = 8;

    function new(string name = "fifo_overflow_seq");
        super.new(name);
    endfunction

    task body();
        fifo_item item;
        for (int i = 0; i < depth + 1; i++) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.op   = FIFO_WRITE;
            item.data = 8'(i + 1);
            finish_item(item);
        end
        for (int i = 0; i < depth; i++) begin
            item = fifo_item::type_id::create("item");
            start_item(item);
            item.op = FIFO_READ;
            finish_item(item);
        end
    endtask
endclass
