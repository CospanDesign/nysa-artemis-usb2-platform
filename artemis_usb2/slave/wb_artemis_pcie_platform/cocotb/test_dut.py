# Simple tests for an adder module
import os
import sys
import cocotb
import logging
from cocotb.result import TestFailure
from nysa.host.sim.sim_host import NysaSim
from nysa.common.print_utils import *
from cocotb.clock import Clock
import time
from array import array as Array
from dut_driver import ArtemisPCIEDriver
from cocotb_pcie_controller import CocotbPCIE

from cocotb.triggers import Timer
from cocotb.triggers import RisingEdge

SIM_CONFIG = "sim_config.json"


CLK_PERIOD = 10

#MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "tools")
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, "tools")))
MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "rtl")
MODULE_PATH = os.path.abspath(MODULE_PATH)

from tlp_manager import TLPManager

def setup_dut(dut):
    cocotb.fork(Clock(dut.clk, CLK_PERIOD).start())

@cocotb.test(skip = False)
def test_write_pcie_register(dut):
    """
    Description:
        Test to make sure that we can write to all the local registers

    Test ID: 0

    Expected Results:
        Values written into the registers are the same as the values read by Cocotb
    """

    dut.test_id = 0

    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    yield cocotb.external(driver.enable)(True)
    c = CocotbPCIE(dut, debug = False)
    #c = CocotbPCIE(dut, debug = True)
    yield (nysa.wait_clocks(100))
    #v = yield cocotb.external(driver.get_control)()


    #Register Writes
    status_addr   = 0x55555555
    buffer_ready  = 0x03
    wr_buf_a_addr = 0x88888888
    wr_buf_b_addr = 0x99999999
    rd_buf_a_addr = 0xAAAAAAAA
    rd_buf_b_addr = 0xBBBBBBBB
    buf_size      = 0x00000800

    c.set_status_buf_addr(status_addr)
    c.set_buffer_ready_status(buffer_ready)
    c.set_write_buf_a_addr(wr_buf_a_addr)
    c.set_write_buf_b_addr(wr_buf_b_addr)
    c.set_read_buf_a_addr(rd_buf_a_addr)
    c.set_read_buf_b_addr(rd_buf_b_addr)
    c.set_buffer_size(buf_size)

    yield (nysa.wait_clocks(300))

    if dut.s1.api.ingress.o_status_addr.value != status_addr:
        cocotb.log.error("Status Buffer Address: 0x%08X != 0x%08X" % (status_addr, dut.s1.api.ingress.o_status_addr.value))
    if dut.s1.api.ingress.o_update_buf.value != buffer_ready:
        cocotb.log.error("Buffer Ready: 0x%08X != 0x%08X" % (buffer_ready, dut.s1.api.ingress.o_update_buf.value))
    if dut.s1.api.ingress.o_write_a_addr.value != wr_buf_a_addr:
        cocotb.log.error("Wr buf A Address: 0x%08X != 0x%08X" % (wr_buf_a_addr, dut.s1.api.ingress.o_write_a_addr.value))
    if dut.s1.api.ingress.o_write_b_addr.value != wr_buf_b_addr:
        cocotb.log.error("Wr buf B Address: 0x%08X != 0x%08X" % (wr_buf_b_addr, dut.s1.api.ingress.o_write_b_addr.value))
    if dut.s1.api.ingress.o_read_a_addr.value != rd_buf_a_addr:
        cocotb.log.error("Rd buf A Address: 0x%08X != 0x%08X" % (rd_buf_a_addr, dut.s1.api.ingress.o_read_a_addr.value))
    if dut.s1.api.ingress.o_read_b_addr.value != rd_buf_b_addr:
        cocotb.log.error("Rd buf B Address: 0x%08X != 0x%08X" % (rd_buf_b_addr, dut.s1.api.ingress.o_read_b_addr.value))
    if dut.s1.api.ingress.o_buffer_size.value != buf_size:
        cocotb.log.error("Buffer Size: 0x%08X != 0x%08X" % (buf_size, dut.s1.api.ingress.o_buffer_size.value))

    yield (nysa.wait_clocks(100))


@cocotb.test(skip = False)
def test_pcie_command(dut):
    """
    Description:
        Write down a command and read the results

    Test ID: 1

    Expected Results:
        A command is observed within the write state machine.
        The control SM processes the command and sends config data to the host
        The host reads the config data back
    """

    dut.test_id = 1
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    yield cocotb.external(driver.enable)(True)
    c = CocotbPCIE(dut, debug = False)
    #c = CocotbPCIE(dut, debug = True)
    yield (nysa.wait_clocks(100))
    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    yield (nysa.wait_clocks(300))
    yield c.read_config_regs(wait_for_ready = False)
    yield (nysa.wait_clocks(500))

@cocotb.test(skip = False)
def test_pcie_config_read_wait_for_ready(dut):
    """
    Description:
        Write down a command and read the results

    Test ID: 2

    Expected Results:
        A command is observed within the write state machine.
        The control SM processes the command and sends config data to the host
        The host reads the config data back
    """

    dut.test_id = 2
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    yield cocotb.external(driver.enable)(True)
    c = CocotbPCIE(dut, debug = False)
    #c = CocotbPCIE(dut, debug = True)
    yield (nysa.wait_clocks(100))
    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    yield (nysa.wait_clocks(300))
    yield c.read_config_regs(wait_for_ready = True)
    #yield c.read_config_regs(wait_for_ready = False)
    yield (nysa.wait_clocks(500))


