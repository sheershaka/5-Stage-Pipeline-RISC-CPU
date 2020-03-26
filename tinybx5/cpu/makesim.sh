#!/bin/bash
#
# This uses Verilator to produce a VCD trace file
# that can be viewed with gtkwave
#
rm -rf obj_dir
rm -f cpu.vcd
verilator --cc --trace cpu.v --exe sim.cpp
make -j -C obj_dir/ -f Vcpu.mk Vcpu
obj_dir/Vcpu
