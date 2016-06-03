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
from dut_driver import riffa_fifo_demoDriver

from cocotb_riffa import CocotbRIFFA

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
def first_test(dut):
    """
    Description:
        Very Simple Read test of 100 dwords
            Startup Nysa

    Test ID: 0

    Expected Results:
        Write to all registers
    """


    dut.test_id <= 0
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_source_total_count)(100)
    yield cocotb.external(driver.set_source_word_count)(100)
    yield cocotb.external(driver.set_source_sleep_count)(10)

    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield cocotb.external(driver.enable_source)(True)
    yield (nysa.wait_clocks(100))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(400))
    v = yield cocotb.external(driver.get_control)()
    dut.log.info("Control: %d" % v)
    #dut.log.info("V: %d" % v)
    #dut.log.info("DUT Opened!")
    dut.log.info("Ready")


@cocotb.test(skip = False)
def multiple_write_block_test(dut):
    """
    Description:
        Very Simple Read test of 100 dwords
            Startup Nysa

    Expected Results:
        Write to all registers
    """


    dut.test_id <= 1
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_source_total_count)(100)
    yield cocotb.external(driver.set_source_word_count)(50)
    yield cocotb.external(driver.set_source_sleep_count)(10)

    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield cocotb.external(driver.enable_source)(True)
    yield (nysa.wait_clocks(100))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(400))
    v = yield cocotb.external(driver.get_control)()
    dut.log.info("Control: %d" % v)
    #dut.log.info("V: %d" % v)
    #dut.log.info("DUT Opened!")
    dut.log.info("Ready")



@cocotb.test(skip = False)
def read_block_test(dut):
    """
    Description:
        Very Simple Read test of 100 dwords
            Startup Nysa

    Expected Results:
        Write to all registers
    """


    dut.test_id <= 2
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_source_total_count)(100)
    yield cocotb.external(driver.set_source_word_count)(100)
    yield cocotb.external(driver.set_source_sleep_count)(10)

    yield cocotb.external(driver.set_sink_word_count)(50)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield cocotb.external(driver.enable_source)(True)
    yield (nysa.wait_clocks(100))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(400))
    v = yield cocotb.external(driver.get_control)()
    dut.log.info("Control: %d" % v)
    #dut.log.info("V: %d" % v)
    #dut.log.info("DUT Opened!")
    dut.log.info("Ready")


@cocotb.test(skip = False)
def riffa_nysa_peripheral_small_write(dut):
    """
    Description:
        Test out simulated nysa interface, write to peripheral

    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 3
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    #yield cocotb.external(driver.set_source_total_count)(100)
    #yield cocotb.external(driver.set_source_word_count)(100)
    #yield cocotb.external(driver.set_source_sleep_count)(10)

    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    #yield cocotb.external(driver.enable_source)(True)
    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)

    DATA = Array('B', [0x00, 0x01, 0x02, 0x03])
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.write_peripheral(ADDR, DATA))
    yield (nysa.wait_clocks(10))


    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_peripheral_long_write(dut):
    """
    Description:
        Test out simulated nysa interface, write to peripheral

    Test ID: 4

    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 4
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)

    length = 100

    DATA = Array('B')
    for i in range(0, length * 4, 4):
        DATA.append((i + 0) % 256)
        DATA.append((i + 1) % 256)
        DATA.append((i + 2) % 256)
        DATA.append((i + 3) % 256)

    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.write_peripheral(ADDR, DATA))
    yield (nysa.wait_clocks(10))

    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_memory_write(dut):
    """
    Description:
        Test out simulated nysa interface, write to memory


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 5
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)

    length = 100

    DATA = Array('B')
    for i in range(0, length * 4, 4):
        DATA.append((i + 0) % 256)
        DATA.append((i + 1) % 256)
        DATA.append((i + 2) % 256)
        DATA.append((i + 3) % 256)

    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.write_memory(ADDR, DATA))
    yield (nysa.wait_clocks(10))

    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_peripheral_read(dut):
    """
    Description:
        Test out simulated nysa interface, write to peripheral


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 6
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 100
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_peripheral(ADDR, length))
    yield (nysa.wait_clocks(10))
    dut.log.info("finishged read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))


    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_dma_write(dut):
    """
    Description:
        Test out simulated nysa interface, write to DMA


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 7
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)

    length = 100

    DATA = Array('B')
    for i in range(0, length * 4, 4):
        DATA.append((i + 0) % 256)
        DATA.append((i + 1) % 256)
        DATA.append((i + 2) % 256)
        DATA.append((i + 3) % 256)

    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.write_dma(ADDR, DATA))
    yield (nysa.wait_clocks(10))

    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_short_peripheral_read(dut):
    """
    Description:
        Test out simulated nysa interface, read a small packet from the peripheral


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 8
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 1
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_peripheral(ADDR, length))
    yield (nysa.wait_clocks(10))
    dut.log.info("finishged read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))


    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_short_memory_read(dut):
    """
    Description:
        Test out simulated nysa interface, read a small packet from the memoryl


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 9
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 1
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_memory(ADDR, length))
    yield (nysa.wait_clocks(10))
    dut.log.info("finished read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))

    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_long_memory_read(dut):
    """
    Description:
        Test out simulated nysa interface, read a small packet from the memory


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 10
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 33
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_memory(ADDR, length))
    yield (nysa.wait_clocks(10))
    dut.log.info("finished read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))


    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_short_peripheral_read(dut):
    """
    Description:
        Test out simulated nysa interface, read a small packet from the peripheral


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 8
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 1
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_peripheral(ADDR, length))
    yield (nysa.wait_clocks(10))
    dut.log.info("finishged read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))


    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_short_dma_read(dut):
    """
    Description:
        Test out simulated nysa interface, read a small packet from the dmal


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 11
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 1
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_dma(ADDR, length))
    yield (nysa.wait_clocks(10))
    dut.log.info("finished read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))

    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_long_dma_read(dut):
    """
    Description:
        Test out simulated nysa interface, read a small packet from the dmal


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 12
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 33
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_dma(ADDR, length))
    yield (nysa.wait_clocks(10))
    dut.log.info("finished read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))


    v = yield cocotb.external(driver.get_control)()


@cocotb.test(skip = False)
def riffa_nysa_long_dma_read_with_delay(dut):
    """
    Description:
        Test out simulated nysa interface, read a small packet from the dmal


    Expected Results:
        Should see the correct stream of a command exist the RIFFA FIFO
    """
    dut.test_id <= 13
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    setup_dut(dut)
    yield(nysa.reset())
    dut.log.info("Test ID: %d" % dut.test_id.value)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    driver = riffa_fifo_demoDriver(nysa, nysa.find_device(riffa_fifo_demoDriver)[0])
    yield(nysa.reset())
    yield cocotb.external(driver.set_sink_word_count)(100)
    yield cocotb.external(driver.set_sink_sleep_count)(10)

    yield (nysa.wait_clocks(10))
    yield cocotb.external(driver.enable_sink)(True)
    yield (nysa.wait_clocks(10))

    riffa = CocotbRIFFA(    dut,
                            dut.s1.cocotb_source,
                            dut.s1.cocotb_source.o_chnl_tx_clk,
                            dut.s1.cocotb_sink,
                            dut.s1.cocotb_sink.o_chnl_rx_clk,
                            debug = True)
    yield(nysa.reset())

    length = 33
    ADDR = 0x01234567

    yield (nysa.wait_clocks(10))
    yield (riffa.read_dma_with_delay(ADDR, length, 10, 1))
    yield (nysa.wait_clocks(10))
    dut.log.info("finished read")
    data = riffa.get_read_data()
    for i in range (0, len(data), 4):
        value = (data[i] << 24) | (data[i + 1] << 16) | (data[i + 2] << 8) | (data[i + 3])
        dut.log.info("[% 3d]: %08X" % (i / 4, value))


    v = yield cocotb.external(driver.get_control)()



