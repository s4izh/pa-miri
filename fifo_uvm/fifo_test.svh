class fifo_test extends uvm_test;
    `uvm_component_utils(fifo_test)

    fifo_env env;

    function new(string name = "fifo_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fifo_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        fifo_write_seq    wr_seq;
        fifo_read_seq     rd_seq;
        fifo_overflow_seq ovf_seq;

        phase.raise_objection(this);

        `uvm_info("TEST", "=== write 4 / read 4 ===", UVM_NONE)
        wr_seq = fifo_write_seq::type_id::create("wr_seq");
        wr_seq.n = 4;
        wr_seq.start(env.agent.sequencer);
        rd_seq = fifo_read_seq::type_id::create("rd_seq");
        rd_seq.n = 4;
        rd_seq.start(env.agent.sequencer);

        `uvm_info("TEST", "=== overflow: write 9 into depth-8 FIFO ===", UVM_NONE)
        ovf_seq = fifo_overflow_seq::type_id::create("ovf_seq");
        ovf_seq.start(env.agent.sequencer);

        #50;
        phase.drop_objection(this);
        #1; $finish;
    endtask

endclass
