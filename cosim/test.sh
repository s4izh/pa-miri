#!/bin/bash

make clean
make all
rm -rf obj_dir/
verilator -sv --cc --exe --build --main --timing sv/test.sv $(pwd)/cosim_dpi.a
./obj_dir/Vtest
