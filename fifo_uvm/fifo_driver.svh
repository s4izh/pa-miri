class fifo_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_driver)

    virtual fifo_if vif;
    uvm_analysis_port #(fifo_item) write_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        write_port = new("write_port", this);
        if (!uvm_config_db #(virtual fifo_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRIVER", "No virtual interface in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        fifo_item item;
        vif.wr_en = 0;
        vif.rd_en = 0;
        @(posedge vif.rst_n);
        forever begin
            seq_item_port.get_next_item(item);
            case (item.op)
                FIFO_WRITE: do_write(item);
                FIFO_READ:  do_read(item);
            endcase
            seq_item_port.item_done();
        end
    endtask

    task do_write(fifo_item item);
        @(negedge vif.clk);
        vif.wr_en   = 1;
        vif.wr_data = item.data;
        @(posedge vif.clk); #1;
        vif.wr_en = 0;
        write_port.write(item);   // always forward -- scoreboard decides what succeeded
    endtask

    task do_read(fifo_item item);
        @(negedge vif.clk);
        vif.rd_en = 1;
        @(posedge vif.clk); #1;
        vif.rd_en = 0;
        @(negedge vif.clk);
    endtask

endclass
