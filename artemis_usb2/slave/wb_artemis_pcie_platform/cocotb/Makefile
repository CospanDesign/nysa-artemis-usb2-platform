
TOPLEVEL_LANG ?= verilog
PWD=$(shell pwd)
TOPDIR=$(PWD)/..
COCOTB 	:= $(shell $(python) nysa paths -c -s)
NYSA 	:= $(shell $(python) nysa paths -s -v nysa-verilog)
PYTHONPATH := ./model:$(PYTHONPATH)
export PYTHONPATH
export PYTHONHOME=$(shell python -c "from distutils.sysconfig import get_config_var; print(get_config_var('prefix'))")

EXTRA_ARGS+=-I$(TOPDIR)/rtl/ -I$(TOPDIR)/sim/ -I$(NYSA)/verilog/ -DSIMULATION -Wall
#EXTRA_ARGS+=-I$(TOPDIR)/rtl/ -I$(TOPDIR)/sim/ -I$(NYSA)/verilog/ -DSIMULATION

#Dependencies
VERILOG_SOURCES = $(NYSA)/verilog/wishbone/master/wishbone_master.v

VERILOG_SOURCES += $(NYSA)/verilog/generic/blk_mem.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/bram.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/dpb.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/cross_clock_strobe.v
VERILOG_SOURCES += $(NYSA)/verilog/generic/cross_clock_enable.v
VERILOG_SOURCES += $(NYSA)/verilog/generic/ppfifo.v

VERILOG_SOURCES += ${TOPDIR}/sim/sim_pcie_axi_bridge.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/adapter_dpb_ppfifo.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/adapter_axi_stream_2_ppfifo.v
VERILOG_SOURCES += ${NYSA}/verilog/generic/adapter_ppfifo_2_axi_stream.v

VERILOG_SOURCES += ${TOPDIR}/rtl/config_parser.v
#VERILOG_SOURCES += ${TOPDIR}/rtl/artemis_pcie_interface.v
VERILOG_SOURCES += ${TOPDIR}/rtl/pcie_control.v
VERILOG_SOURCES += ${TOPDIR}/rtl/pcie_egress.v
VERILOG_SOURCES += ${TOPDIR}/rtl/pcie_ingress.v
VERILOG_SOURCES += ${TOPDIR}/rtl/artemis_pcie_controller.v


VERILOG_SOURCES += ${NYSA}/verilog/wishbone/slave/wb_bram/rtl/wb_bram.v
VERILOG_SOURCES += $(NYSA)/verilog/sim/wishbone/interconnect/example_2port_interconnect/wishbone_interconnect.v
VERILOG_SOURCES += ${TOPDIR}/sim/arbiter_2_masters.v
VERILOG_SOURCES += ${TOPDIR}/sim/wishbone_mem_interconnect.v

#Simulation Devices
VERILOG_SOURCES += ${TOPDIR}/rtl/wb_artemis_pcie_platform.v
#DUT
#Test Benches
VERILOG_SOURCES += $(TOPDIR)/cocotb/tb_cocotb.v

TOPLEVEL = tb_cocotb

GPI_IMPL := vpi

export TOPLEVEL_LANG
MODULE=test_dut

include $(COCOTB)/makefiles/Makefile.inc
include $(COCOTB)/makefiles/Makefile.sim

.PHONY: wave test
wave:
	gtkwave waveforms.gtkw &


