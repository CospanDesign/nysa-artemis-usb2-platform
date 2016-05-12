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
from cocotb_pcie_controller import NysaPCIEConfig
from cocotb_pcie_controller import array_to_dword

from cocotb_pcie_controller import HDR_STATUS_BUF_ADDR
from cocotb_pcie_controller import HDR_BUFFER_READY
from cocotb_pcie_controller import HDR_WRITE_BUF_A_ADDR
from cocotb_pcie_controller import HDR_WRITE_BUF_B_ADDR
from cocotb_pcie_controller import HDR_READ_BUF_A_ADDR
from cocotb_pcie_controller import HDR_READ_BUF_B_ADDR
from cocotb_pcie_controller import HDR_BUFFER_SIZE
from cocotb_pcie_controller import HDR_PING_VALUE
from cocotb_pcie_controller import HDR_DEV_ADDR
from cocotb_pcie_controller import STS_DEV_STATUS
from cocotb_pcie_controller import STS_BUF_RDY
from cocotb_pcie_controller import STS_BUF_POS
from cocotb_pcie_controller import STS_INTERRUPT

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

@cocotb.test(skip = True)
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
    status_addr     = 0x55555555
    buffer_ready    = 0x03
    wr_buf_a_addr   = 0x88888888
    wr_buf_b_addr   = 0x99999999
    rd_buf_a_addr   = 0xAAAAAAAA
    rd_buf_b_addr   = 0xBBBBBBBB
    buf_size        = 0x00000800
    dev_addr        = 0x00000000

    c.set_status_buf_addr(status_addr)
    c.set_buffer_ready_status(buffer_ready)
    c.set_write_buf_a_addr(wr_buf_a_addr)
    c.set_write_buf_b_addr(wr_buf_b_addr)
    c.set_read_buf_a_addr(rd_buf_a_addr)
    c.set_read_buf_b_addr(rd_buf_b_addr)
    c.set_dword_buffer_size(buf_size)
    c.set_dev_addr(dev_addr)

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
        cocotb.log.error("Buffer Size: 0x%08X != 0x%08X" % (buf_size, dut.s1.api.ingress.o_dword_buffer_size.value))
    if dut.s1.api.ingress.o_dev_addr.value != dev_addr:
        cocotb.log.error("Device Address: 0x%08X != 0x%08X" % (dev_addr, dut.s1.api.ingress.o_dev_addr.value))
    yield (nysa.wait_clocks(100))


@cocotb.test(skip = True)
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

@cocotb.test(skip = True)
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

@cocotb.test(skip = True)
def test_pcie_small_read_command(dut):
    """
    Description:
        Request a small read, this doesn't pass the Buffer Boundary

    Test ID: 3

    Expected Results:
        Set up the Core with all the appropriate registers
        Populate the local buffer with an incrementing number pattern
        Request 0x300 words of data, the core should
            -Send 0x200 data
            -Send 0x200 data (0x100) is valid
            -Send Status Block with Done bit
    """

    dut.test_id = 3
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

    data = Array('B')
    for i in range(128 * 4):
        v = i * 4
        data.append((v + 0) % 256)
        data.append((v + 1) % 256)
        data.append((v + 2) % 256)
        data.append((v + 3) % 256)

    yield (nysa.wait_clocks(50))
    yield cocotb.external(driver.write_local_buffer)(data)
    yield (nysa.wait_clocks(50))
    yield cocotb.external(driver.enable_egress_fifo_send)(True)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    yield (nysa.wait_clocks(400))

    COUNT = 0x0300
    ADDRESS = 0x00
    yield c.read_pcie_data(address = ADDRESS, count = COUNT)

@cocotb.test(skip = True)
def test_pcie_read_two_block_command(dut):
    """
    Description:
        Perform a read that spans across two blocks

    Test ID: 4

    Expected Results:
        Set up the Core with all the appropriate registers, this time,
            change the block size to be much smaller so that it will be
            forced to jump across a boundary
        Populate the local buffer with an incrementing number pattern
        Request 0x600 words of data, the core should
            -Send 0x200 data
            -Send 0x200 data, this is the last of the block
            -Send Status Block indicating the block is done
            -Send 0x200 data this is the last packet
            -Send Status Block indicating the transfer is done

    """

    dut.test_id = 4
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

    data = Array('B')
    for i in range(128 * 4):
        v = i * 4
        data.append((v + 0) % 256)
        data.append((v + 1) % 256)
        data.append((v + 2) % 256)
        data.append((v + 3) % 256)

    yield (nysa.wait_clocks(50))
    yield cocotb.external(driver.write_local_buffer)(data)
    yield (nysa.wait_clocks(50))
    yield cocotb.external(driver.enable_egress_fifo_send)(True)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")
    c.set_dword_buffer_size(0x0200)
    yield (nysa.wait_clocks(50))

    cocotb.log.info("Request 0x600 words from the device")
    COUNT = 0x0500
    ADDRESS = 0x00
    yield (nysa.wait_clocks(50))
    yield c.read_pcie_data(address = ADDRESS, count = COUNT)


@cocotb.test(skip = True)
def test_pcie_write_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 5

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 5
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

    COUNT = 16
    ADDRESS = 0x00

    data = Array('B')
    for i in range(COUNT * 4):
        v = i * 4
        data.append((v + 0) % 256)
        data.append((v + 1) % 256)
        data.append((v + 2) % 256)
        data.append((v + 3) % 256)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")
    c.set_dword_buffer_size(0x0200)


    yield (nysa.wait_clocks(50))
    #yield (c.write_pcie_data_command)(ADDRESS, len(data))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))

@cocotb.test(skip = True)
def test_pcie_write_med_length_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 6

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 6
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

    BYTE_COUNT = 0x10
    ADDRESS = 0x00

    data = Array('B')
    for i in range(BYTE_COUNT / 4):
        v = i * 4
        data.append((v + 0) % 256)
        data.append((v + 1) % 256)
        data.append((v + 2) % 256)
        data.append((v + 3) % 256)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    #cocotb.log.info("Reduce the block size to 0x400")
    #c.set_dword_buffer_size(0x1000)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))


@cocotb.test(skip = True)
def test_pcie_write_medium_length_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 7

    Expected Results:
        Enough Data is sent from the host to the device that multiple tags must be used
    """

    dut.test_id = 7
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

    BYTE_COUNT = 640
    ADDRESS = 0x00

    data = Array('B')
    for i in range(BYTE_COUNT):
        data.append(i % 256)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    #cocotb.log.info("Reduce the block size to 0x400")
    #c.set_dword_buffer_size(0x1000)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))



@cocotb.test(skip = True)
def test_pcie_write_multiple_buffers(dut):
    """
    Description:
        Perform a long write

    Test ID: 8

    Expected Results:
        Enough Data is sent from the host to the device that two buffers must be used
    """

    dut.test_id = 8
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

    BUFFER_SIZE = 4096
    BYTE_COUNT = BUFFER_SIZE * 2
    ADDRESS = 0x00

    data = Array('B')
    for i in range(BYTE_COUNT / 4):
        v = i * 4
        data.append((v + 0) % 256)
        data.append((v + 1) % 256)
        data.append((v + 2) % 256)
        data.append((v + 3) % 256)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    #cocotb.log.info("Reduce the block size to 0x400")
    #c.set_dword_buffer_size(0x1000)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))


#@cocotb.test(skip = False)
@cocotb.test(skip = False)
def test_pcie_write_three_buffers(dut):
    """
    Description:
        Perform a long write

    Test ID: 9

    Expected Results:
        Enough Data is sent from the host to the device that three buffers must be used
    """

    dut.test_id = 9
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

    BUFFER_SIZE = 4096
    BYTE_COUNT = BUFFER_SIZE * 3
    ADDRESS = 0x00

    data = Array('B')
    for i in range(BYTE_COUNT / 4):
        v = i * 4
        data.append((v + 0) % 256)
        data.append((v + 1) % 256)
        data.append((v + 2) % 256)
        data.append((v + 3) % 256)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    #cocotb.log.info("Reduce the block size to 0x400")
    #c.set_dword_buffer_size(0x1000)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))

