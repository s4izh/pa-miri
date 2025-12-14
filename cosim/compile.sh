#!/bin/bash

make clean -C c/
make all -C c/
verilator -sv --cc --exe --build --main --timing sv/test.sv $(pwd)/c/cosim_dpi.a
