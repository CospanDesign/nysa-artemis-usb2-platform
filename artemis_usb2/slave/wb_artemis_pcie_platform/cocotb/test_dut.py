# Simple tests for an adder module
import os
import sys
import cocotb
import logging
from cocotb.result import TestFailure
from nysa.host.sim.sim_host import NysaSim
from cocotb.clock import Clock
import time
from array import array as Array
from dut_driver import ArtemisPCIEDriver

SIM_CONFIG = "sim_config.json"


CLK_PERIOD = 10

MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "rtl")
MODULE_PATH = os.path.abspath(MODULE_PATH)


def setup_dut(dut):
    cocotb.fork(Clock(dut.clk, CLK_PERIOD).start())

@cocotb.coroutine
def wait_ready(nysa, dut):

    #while not dut.hd_ready.value.get_value():
    #    yield(nysa.wait_clocks(1))

    #yield(nysa.wait_clocks(100))
    pass

@cocotb.test(skip = False)
def test_local_buffer(dut):
    """
    Description:
        Test to make sure that we can read/write to/from local buffer

    Test ID: 0

    Expected Results:
        Data written into the buffer is the same as the data read out of the buffer
    """

    dut.test_id = 0
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    yield cocotb.external(driver.enable)(True)
    yield (nysa.wait_clocks(100))
    v = yield cocotb.external(driver.get_control)()

    dut.log.info("V: %d" % v)


    dut.log.info("Write to the local buffer")
    size = yield cocotb.external(driver.get_local_buffer_size)()
    data_out = Array("B")
    for i in range (0, size, 4):
        data_out.append((i + 0) % 256)
        data_out.append((i + 1) % 256)
        data_out.append((i + 2) % 256)
        data_out.append((i + 3) % 256)

    if len(data_out) > 0:
        yield cocotb.external(driver.write_local_buffer)(data_out)

    yield (nysa.wait_clocks(100))

    data_in = yield cocotb.external(driver.read_local_buffer)()

    error_count = 0
    for i in range(len(data_in)):
        if data_in[i] != data_out[i]:
            error_count += 1
            if error_count < 16:
                print "Data Out != Data In @ 0x%02X 0x%02X != 0x%02X" % (i, data_out[i], data_in[i])

    if error_count > 0:
        print "Found Errors in the local buffer"

    yield (nysa.wait_clocks(100))

    dut.log.info("Enable PPFIFO 2 Local Memory")
    yield cocotb.external(driver.enable_pcie_read_block)(True)
    yield (nysa.wait_clocks(100))
    yield cocotb.external(driver.enable_pcie_read_block)(False)
    yield (nysa.wait_clocks(1000))
    data_in = yield cocotb.external(driver.read_local_buffer)()


@cocotb.test(skip = False)
def test_local_buffer_to_pcie(dut):
    """
    Description:
        Write to the local buffer and send the data out over PCIE

    Test ID: 1

    Expected Results:
        Data written into the buffer is the same as the data read out of the buffer
    """


    dut.test_id = 1
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    yield cocotb.external(driver.enable)(True)
    yield (nysa.wait_clocks(100))
    v = yield cocotb.external(driver.get_control)()


    dut.log.info("Write to the local buffer")
    size = yield cocotb.external(driver.get_local_buffer_size)()
    data_out = Array("B")
    for i in range (size):
        data_out.append(i % 256)

    if len(data_out) > 0:
        yield cocotb.external(driver.write_local_buffer)(data_out)

    yield (nysa.wait_clocks(100))

    yield cocotb.external(driver.send_block_from_local_buffer)()
    yield (nysa.wait_clocks(100))

@cocotb.test(skip = False)
def test_config_read(dut):
    """
    Description:
        Write to the local buffer and send the data out over PCIE

    Test ID: 2

    Expected Results:
        Data written into the buffer is the same as the data read out of the buffer
    """


    dut.test_id = 2
    print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    yield cocotb.external(driver.enable)(True)
    yield (nysa.wait_clocks(100))
    v = yield cocotb.external(driver.get_control)()


    dut.log.info("Write to the local buffer")
    size = yield cocotb.external(driver.get_local_buffer_size)()
    data_out = Array("B")
    for i in range (size):
        data_out.append(i % 256)

    if len(data_out) > 0:
        yield cocotb.external(driver.write_local_buffer)(data_out)

    yield (nysa.wait_clocks(100))

    yield cocotb.external(driver.send_block_from_local_buffer)()
    yield (nysa.wait_clocks(100))
    yield cocotb.external(driver.get_config_data)()
    yield (nysa.wait_clocks(100))

