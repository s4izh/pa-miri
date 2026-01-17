-- TODO have a table to relate env variables to config variables
-- and verify that they are all set with a function internally
-- I essentially want the api to be harness.env and pass a config table with the variables
build_dir = os.getenv("BUILD_DIR")
if not build_dir then
    error("BUILD_DIR not set")
end

-- should be harness.env(key = value table) instead
harness.set_build_dir(build_dir)

local function merge(...)
    local tables_to_merge = {...}
    local result = {}
    for _, t in ipairs(tables_to_merge) do
        if type(t) == "table" then
            for k, v in pairs(t) do
                result[k] = v
            end
        end
    end
    return result
end

local function dump(o, indent)
    indent = indent or 0
    local spacing = string.rep("  ", indent)

    if type(o) == 'table' then
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. spacing .. "  [" .. k .. "] = " .. dump(v, indent + 1) .. ",\n"
        end
        return s .. spacing .. '}'
    else
        return tostring(o)
    end
end

local cfg = {
    cflags_base = "-march=rv32im -mabi=ilp32 -Iprograms -g ",
    toolchain_prefix = "riscv32-none-elf-"
}

local cosim = harness.add_task({
    tasks_namespace = "cosim",
    name = "build_dpi",
    source_dir = "cosim",
    command = "git submodule init && git submodule update && BUILD_DIR=$abs_out_dir make -C $source_dir $abs_out_dir/cosim_dpi.a",
    inputs = harness.list_files("cosim/**"),
    vars = {
        debug = "0"
    },
    outputs = {
        lib = "cosim_dpi.a"
    }
})

local crt = harness.add_task({
    name = "compile_crt",
    tasks_namespace = "env",
    command = cfg.toolchain_prefix .. "gcc $cflags -c programs/crt.s -o $abs_out_dir/crt.o",
    inputs = { "programs/crt.s" },
    vars = {
        cflags = cfg.cflags_base,
    },
    outputs = {
        obj = "crt.o"
    }
})

harness.add_tool({
    name = "riscv_gcc",
    actions = {
        {
            name = "compile",
            command = cfg.toolchain_prefix .. "gcc $cflags -c $in -o $obj",
            inputs = {},
            outputs = {
                { name = "obj", filename = "prog.o" }
            }
        },
        {
            name = "link",
            command = cfg.toolchain_prefix .. "gcc $cflags -T $ld -nostdlib -Wl,-Map,$map $crt_obj $obj -o $elf",
            inputs = { "obj" },
            outputs = {
                { name = "elf", filename = "prog.elf" },
                { name = "map", filename = "prog.map" }
            }
        },
        {
            name = "rom",
            command = cfg.toolchain_prefix .. "objcopy -O verilog --verilog-data-width 16 " ..
                      "--only-section=.text* " ..
                      "$elf $out_dir/rom.tmp && " ..
                      "cat $out_dir/rom.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $rom && " ..
                      "rm $out_dir/rom.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "rom", filename = "rom.hex" }
            }
        },
        {
            name = "sram",
            command = cfg.toolchain_prefix .. "objcopy -O verilog --verilog-data-width 16 " ..
                      "--only-section=.rodata* " ..
                      "--only-section=.data* " ..
                      "--only-section=.sdata* " ..
                      "--only-section=.bss* " ..
                      "--only-section=.sbss* " ..
                      "$elf $out_dir/sram.tmp && " ..
                      "cat $out_dir/sram.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $sram && " ..
                      "rm $out_dir/sram.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "sram", filename = "sram.hex" }
            }
        },
        {
            name = "mem",
            command = cfg.toolchain_prefix .. "objcopy -O verilog --verilog-data-width 16 " ..
                      "--only-section=.text* " ..
                      "--only-section=.rodata* " ..
                      "--only-section=.data* " ..
                      "--only-section=.sdata* " ..
                      "--only-section=.bss* " ..
                      "--only-section=.sbss* " ..
                      "$elf $out_dir/sramunified.tmp && " ..
                      "cat $out_dir/sramunified.tmp | tr -s ' ' '\\n' | tr -d '\\r' > $mem && " ..
                      "rm $out_dir/sramunified.tmp",
            inputs = { "elf" },
            outputs = {
                { name = "mem", filename = "mem.hex" }
            }
        },
        {
            name = "dump",
            command = cfg.toolchain_prefix .. "objdump -S $elf > $out_dir/prog.dump ",
            inputs = { "elf" },
            outputs = {
                { name = "dump", filename = "prog.dump" }
            }
        }
    }
})

-- Software Suite definitions
harness.add_suite({
    name = "isa",
    base_dir = "programs/tohost_tests",
    pattern = "**/*.s",
    tool = "riscv_gcc",
    plusargs = {},
    vars = {
        cflags = cfg.cflags_base,
        ld = "programs/link.ld"
    },
    program_overrides = {},
    sw_deps = {}
})

harness.add_suite({
    name = "isa_opt",
    base_dir = "programs/tohost_tests",
    pattern = "**/*.s",
    tool = "riscv_gcc",
    plusargs = {},
    vars = {
        cflags = cfg.cflags_base .. "-O3",
        ld = "programs/link.ld"
    },
    program_overrides = {},
    sw_deps = {}
})

harness.add_suite({
    name = "benchmarks",
    base_dir = "programs/benchmarks",
    pattern = "**/*.c",
    tool = "riscv_gcc",
    plusargs = {},
    vars = {
        cflags = cfg.cflags_base .. "-O0",
        ld = "programs/link.ld",
        crt_obj = harness.abspath(crt.outputs.obj) 
    },
    program_overrides = {},
    sw_deps = { crt.outputs.obj } 
})

-- Simulator definitions
harness.add_simulator({
    name = "verilator",
    compile_rule = "verilator -j 8 --cc --binary --build -O3 --trace-fst --trace-structs --timing -f $filelist --top-module top_tb_wrapper --Mdir $out_dir -o Vtop",
    outputs = {
        { name = "bin", filename = "Vtop" }
    },
    default_run_rule = "$bin $plusargs"
})

harness.add_simulator({
    name = "vsim",
    compile_rule = 
        "rm -rf $out_dir/work && " ..
        "tools/vsim_container.sh " ..
        "\"vlog -sv -createlib -timescale \\\"1ns/1ps\\\" -work $out_dir/work -f $filelist -l $out_dir/compile.log\" && " ..
        "echo '#!/bin/sh' > $out_dir/run_vsim && " ..
        "echo 'exec tools/vsim_container.sh vsim -c -work $out_dir/work -do \"log -r /*; run -all; quit\" top_tb_wrapper \"$$@\"' >> $out_dir/run_vsim && " ..
        "chmod +x $out_dir/run_vsim",
    outputs = {
        { name = "bin", filename = "run_vsim" }
    },
    default_run_rule = "$bin $plusargs"
})

-- Testbench definitions
harness.add_testbench({
    name = "rv_pa3.anyrom",
    filelist = "sim/rv_pa3/anyrom/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +ROM_FILE=$rom +SRAM_FILE=$sram +TIMEOUT_CYCLES=10000",
    sw_deps = {}
})

harness.add_testbench({
    name = "rv_pa3.cosim",
    filelist = "sim/rv_pa3/cosim/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +ROM_FILE=$rom +SRAM_FILE=$sram +TIMEOUT_CYCLES=10000",
    vars = {
          COSIM_DPI_LIB = harness.abspath(cosim.outputs.lib)
    },
    sw_deps = { cosim.outputs.lib },
})

harness.add_testbench({
    name = "gandul.anyrom",
    filelist = "sim/gandul/anyrom/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +SRAM_FILE=$mem +TIMEOUT_CYCLES=10000",
    sw_deps = {}
})

harness.add_testbench({
    name = "gandul.cosim",
    filelist = "sim/gandul/cosim/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +SRAM_FILE=$mem +TIMEOUT_CYCLES=1000000",
    vars = {
          COSIM_DPI_LIB = harness.abspath(cosim.outputs.lib)
    },
    sw_deps = { cosim.outputs.lib },
})

harness.add_testbench({
    name = "common.rob",
    filelist = "sim/common/rob/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +TIMEOUT_CYCLES=10000",
    sw_deps = {}
})

harness.add_testbench({
    name = "common.store_buffer",
    filelist = "sim/common/store_buffer/filelist.f",
    run_template = "$bin $plusargs +VCD_FILE=waves.fst +TIMEOUT_CYCLES=10000",
    sw_deps = {}
})

local defines_base = {
    DELAYER_LEN         = "5",
    SB_ENABLE           = "1",
    SB_N_ENTRIES        = "8",
    SB_DRAIN_THRESHOLD  = "1",
    ROB_N_ENTRIES       = "8",
    DCACHE_STORE_POLICY = '"wb"',
    XLEN                = "32",
    MEM_SIZE_KB         = "2*1024",
    CACHE_SETS          = "4",
    CACHE_WAYS          = "4",
}

harness.add_param_set({
    name = "base",
    defines = defines_base,
    plusargs = {},
    sim_templates = {}
})

harness.add_param_set({
    name = "base_wt",
    defines = merge(defines_base, {
        DCACHE_STORE_POLICY = '"wt"',
    }),
    plusargs = {},
    sim_templates = {}
})

harness.add_param_set({
    name = "delayer_10",
    defines = merge(defines_base, {
        DELAYER_LEN = "10",
    }),
    plusargs = {},
    sim_templates = {}
})

harness.add_param_set({
    name = "delayer_1",
    defines = merge(defines_base, {
        DELAYER_LEN = "1",
    }),
    plusargs = {},
    sim_templates = {}
})

harness.add_experiment({
    name = "regression",
    testbench = "rv_pa3.anyrom",
    param_sets = { "base", "delayer_1", "delayer_10" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "opt",
    testbench = "rv_pa3.anyrom",
    param_sets = { "base" },
    suites = { "isa", "isa_opt" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "rv_pa3_cosim",
    testbench = "rv_pa3.cosim",
    param_sets = { "base" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "rob",
    testbench = "common.rob",
    param_sets = { "base" },
    suites = {}, -- standalone HW test, no software suite involved
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "store_buffer",
    testbench = "common.store_buffer",
    param_sets = { "base" },
    suites = {}, -- standalone HW test, no software suite involved
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul",
    testbench = "gandul.anyrom",
    param_sets = { "base" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul-benchmarks",
    testbench = "gandul.anyrom",
    param_sets = { "base" },
    suites = { "benchmarks" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul-cosim",
    testbench = "gandul.cosim",
    param_sets = { "base", "base_wt" };
    -- param_sets = { "base", "base_wt", "delayer_1", "delayer_10" },
    suites = { "isa" },
    simulators = { "verilator" }
})

harness.add_experiment({
    name = "gandul-cosim-benchmarks",
    testbench = "gandul.cosim",
    param_sets = { "base", "base_wt", "delayer_1", "delayer_10" },
    suites = { "benchmarks" },
    simulators = { "verilator" }
})
