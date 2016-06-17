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
from cocotb_pcie_controller import HDR_DEV_ADDR
from cocotb_pcie_controller import STS_DEV_STATUS
from cocotb_pcie_controller import STS_BUF_RDY
from cocotb_pcie_controller import STS_BUF_POS
from cocotb_pcie_controller import STS_INTERRUPT

from cocotb.triggers import Timer
from cocotb.triggers import RisingEdge
from cocotb.triggers import ReadOnly

SIM_CONFIG = "sim_config.json"


CLK_PERIOD = 10
PCIE_CLK_PERIOD = 16

#MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "tools")
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, "tools")))
MODULE_PATH = os.path.join(os.path.dirname(__file__), os.pardir, "rtl")
MODULE_PATH = os.path.abspath(MODULE_PATH)

from tlp_manager import TLPManager

def convert_dword_to_byte_array(dword):
    d = Array('B')
    d.append((dword >> 24) & 0xFF)
    d.append((dword >> 16) & 0xFF)
    d.append((dword >>  8) & 0xFF)
    d.append((dword >>  0) & 0xFF)
    return d

@cocotb.coroutine
def setup_dut(dut):
    dut.s1.host_interface.api.pcie_interface.user_reset_out <= 1;
    cocotb.fork(Clock(dut.s1.host_interface.api.pcie_interface.user_clk_out, PCIE_CLK_PERIOD).start())
    for i in range(20):
        yield RisingEdge(dut.s1.host_interface.api.pcie_interface.user_clk_out)
        yield ReadOnly()
    dut.s1.host_interface.api.pcie_interface.user_reset_out <= 0;

#@cocotb.test(skip = True)
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
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
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

    if dut.s1.host_interface.api.ingress.o_status_addr.value != status_addr:
        cocotb.log.error("Status Buffer Address: 0x%08X != 0x%08X" % (status_addr, dut.s1.host_interface.api.ingress.o_status_addr.value))
    if dut.s1.host_interface.api.ingress.o_update_buf.value != buffer_ready:
        cocotb.log.error("Buffer Ready: 0x%08X != 0x%08X" % (buffer_ready, dut.s1.host_interface.api.ingress.o_update_buf.value))
    if dut.s1.host_interface.api.ingress.o_write_a_addr.value != wr_buf_a_addr:
        cocotb.log.error("Wr buf A Address: 0x%08X != 0x%08X" % (wr_buf_a_addr, dut.s1.host_interface.api.ingress.o_write_a_addr.value))
    if dut.s1.host_interface.api.ingress.o_write_b_addr.value != wr_buf_b_addr:
        cocotb.log.error("Wr buf B Address: 0x%08X != 0x%08X" % (wr_buf_b_addr, dut.s1.host_interface.api.ingress.o_write_b_addr.value))
    if dut.s1.host_interface.api.ingress.o_read_a_addr.value != rd_buf_a_addr:
        cocotb.log.error("Rd buf A Address: 0x%08X != 0x%08X" % (rd_buf_a_addr, dut.s1.host_interface.api.ingress.o_read_a_addr.value))
    if dut.s1.host_interface.api.ingress.o_read_b_addr.value != rd_buf_b_addr:
        cocotb.log.error("Rd buf B Address: 0x%08X != 0x%08X" % (rd_buf_b_addr, dut.s1.host_interface.api.ingress.o_read_b_addr.value))
    if dut.s1.host_interface.api.ingress.o_buffer_size.value != buf_size:
        cocotb.log.error("Buffer Size: 0x%08X != 0x%08X" % (buf_size, dut.s1.host_interface.api.ingress.o_dword_buffer_size.value))
    if dut.s1.host_interface.api.ingress.o_dev_addr.value != dev_addr:
        cocotb.log.error("Device Address: 0x%08X != 0x%08X" % (dev_addr, dut.s1.host_interface.api.ingress.o_dev_addr.value))
    yield (nysa.wait_clocks(100))


@cocotb.test(skip = True)
def test_simple_nysa_write_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 1

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 1

    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    yield(nysa.reset())
    yield(setup_dut(dut))


    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS     = 0x00

    idword      = 0xCD15DBE5
    command     = 0x00000001
    data_count  = 0x00000001
    address     = 0x01000000
    d           = 0x01234567

    data = Array('B')
    data.extend(convert_dword_to_byte_array(idword))
    data.extend(convert_dword_to_byte_array(command))
    data.extend(convert_dword_to_byte_array(data_count))
    data.extend(convert_dword_to_byte_array(address))
    data.extend(convert_dword_to_byte_array(d))

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")
    c.set_dword_buffer_size(0x0200)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))

    value = yield cocotb.external(driver.get_dbg_id_value)()
    cocotb.log.info("ID: 0x%08X" % value)
    value = yield cocotb.external(driver.get_dbg_command_value)()
    cocotb.log.info("COMMAND: 0x%08X" % value)
    value = yield cocotb.external(driver.get_dbg_count_value)()
    cocotb.log.info("COUNT: 0x%08X" % value)
    value = yield cocotb.external(driver.get_dbg_address_value)()
    cocotb.log.info("ADDRESS: 0x%08X" % value)

    value = yield cocotb.external(driver.is_link_up)()
    cocotb.log.info("Linkup: %s" % value)
    value = yield cocotb.external(driver.is_read_idle)()
    cocotb.log.info("Read Idle: %s" % value)
    value = yield cocotb.external(driver.is_peripheral_bus_selected)()
    cocotb.log.info("Peripheral Bus Selected: %s" % value)
    value = yield cocotb.external(driver.is_memory_bus_selected)()
    cocotb.log.info("Memory Bus Selected: %s" % value)
    value = yield cocotb.external(driver.is_dma_bus_selected)()
    cocotb.log.info("DMA Bus Selected: %s" % value)
    value = yield cocotb.external(driver.is_write_enabled)()
    cocotb.log.info("Write Enabled: %s" % value)
    value = yield cocotb.external(driver.is_read_enabled)()
    cocotb.log.info("Read Enabled: %s" % value)




@cocotb.test(skip = True)
def test_long_nysa_write_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 2

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 2
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS     = 0x00

    idword      = 0xCD15DBE5
    command     = 0x00000001
    data_count  = 0x00000010
    #data_count  = 0x00000001
    address     = 0x01000000

    data = Array('B')
    data.extend(convert_dword_to_byte_array(idword))
    data.extend(convert_dword_to_byte_array(command))
    data.extend(convert_dword_to_byte_array(data_count))
    data.extend(convert_dword_to_byte_array(address))
    for i in range (0, data_count * 4, 4):
        d = Array('B')
        d.append((i + 0) % 256)
        d.append((i + 1) % 256)
        d.append((i + 2) % 256)
        d.append((i + 3) % 256)
        data.extend(d)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")
    #c.set_dword_buffer_size(0x0200)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))



@cocotb.test(skip = False)
def test_simple_nysa_read_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 3

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 3
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS     = 0x00

    idword      = 0xCD15DBE5
    command     = 0x00000002
    data_count  = 0x00000001
    address     = 0x01000000

    data = Array('B')
    data.extend(convert_dword_to_byte_array(idword))
    data.extend(convert_dword_to_byte_array(command))
    data.extend(convert_dword_to_byte_array(data_count))
    data.extend(convert_dword_to_byte_array(address))

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")
    c.set_dword_buffer_size(0x0200)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(50))
    yield c.read_pcie_data(address = ADDRESS, count = data_count)
    yield (nysa.wait_clocks(400))
    data = c.get_pcie_read_data()[16:]
    cocotb.log.info("Data:")
    for i in range(0, len(data), 4):
       cocotb.log.info("\t0x%08X" % array_to_dword(data[i:i + 4]))


@cocotb.test(skip = True)
def test_long_nysa_read_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 4

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 4
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS     = 0x00

    idword      = 0xCD15DBE5
    command     = 0x00000002
    data_count  = 0x00000800
    address     = 0x01000000

    data = Array('B')
    data.extend(convert_dword_to_byte_array(idword))
    data.extend(convert_dword_to_byte_array(command))
    data.extend(convert_dword_to_byte_array(data_count))
    data.extend(convert_dword_to_byte_array(address))

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")
    #c.set_dword_buffer_size(0x0200)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(50))
    yield c.read_pcie_data(address = ADDRESS, count = data_count + 4)
    yield (nysa.wait_clocks(400))
    data = c.get_pcie_read_data()[16:]
    cocotb.log.info("Data:")
    for i in range(0, len(data), 4):
       cocotb.log.info("\t0x%08X" % array_to_dword(data[i:i + 4]))

@cocotb.test(skip = True)
def test_short_nysa_mem_write_command(dut):
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
    setup_dut(dut)
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS = 0x04
    data_count  = 1
    data = Array('B')
    for i in range (0, data_count * 4, 4):
        d = Array('B')
        d.append((i + 0) % 256)
        d.append((i + 1) % 256)
        d.append((i + 2) % 256)
        d.append((i + 3) % 256)
        data.extend(d)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data, mem = True)
    yield (nysa.wait_clocks(400))

    '''
    ADDRESS = 0x01
    data_count  = 0x800
    data = Array('B')
    for i in range (0, data_count * 4, 4):
        d = Array('B')
        d.append((i + 0) % 256)
        d.append((i + 1) % 256)
        d.append((i + 2) % 256)
        d.append((i + 3) % 256)
        data.extend(d)

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data, mem = True)
    yield (nysa.wait_clocks(400))
    '''


@cocotb.test(skip = True)
def test_simple_nysa_mem_read_command(dut):
    """
    Description:
        Perform a small read from memory

    Test ID: 6

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 6
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS     = 0x08
    data_count  = 0x010

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()

    yield (nysa.wait_clocks(400))
    yield c.read_pcie_data(address = ADDRESS, count = data_count, mem = True)
    yield (nysa.wait_clocks(400))
    data = c.get_pcie_read_data()
    cocotb.log.info("Data:")
    for i in range(0, len(data), 4):
       cocotb.log.info("\t0x%08X" % array_to_dword(data))

@cocotb.test(skip = True)
def test_short_nysa_dma_write_command(dut):
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
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
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
    data = yield cocotb.external(driver.read_local_buffer)()




    ADDRESS = 0x04
    data_count  = 0x10
    data = Array('B')
    for i in range (0, data_count * 4, 4):
        d = Array('B')
        d.append((i + 0) % 256)
        d.append((i + 1) % 256)
        d.append((i + 2) % 256)
        d.append((i + 3) % 256)
        data.extend(d)

    c.configure_FPGA()

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data, dma = True)
    yield (nysa.wait_clocks(400))


@cocotb.test(skip = True)
def test_long_nysa_dma_write_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 7

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 7
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS = 0x04
    data_count  = 0x900
    data = Array('B')
    for i in range (0, data_count * 4, 4):
        d = Array('B')
        d.append((i + 0) % 256)
        d.append((i + 1) % 256)
        d.append((i + 2) % 256)
        d.append((i + 3) % 256)
        data.extend(d)

    c.configure_FPGA()

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data, dma = True)
    yield (nysa.wait_clocks(400))




#@cocotb.test(skip = True)
def test_simple_nysa_dma_read_command(dut):
    """
    Description:
        Perform a small read from memory

    Test ID: 8

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 8
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS     = 0x08
    data_count  = 0x010

    c.configure_FPGA()

    yield (nysa.wait_clocks(400))
    yield c.read_pcie_data(address = ADDRESS, count = data_count, dma = True)
    yield (nysa.wait_clocks(400))
    data = c.get_pcie_read_data()
    cocotb.log.info("Data:")
    for i in range(0, len(data), 4):
       cocotb.log.info("\t0x%08X" % array_to_dword(data))


@cocotb.test(skip = True)
def test_simple_nysa_write_err_command(dut):
    """
    Description:
        Perform a simple write

    Test ID: 9

    Expected Results:
        Data is sent from the host to the device
    """

    dut.test_id = 9
    #print "module path: %s" % MODULE_PATH
    nysa = NysaSim(dut, SIM_CONFIG, CLK_PERIOD, user_paths = [MODULE_PATH])
    #setup_dut(dut)
    yield(nysa.reset())
    yield(setup_dut(dut))
    nysa.read_sdb()
    yield (nysa.wait_clocks(10))
    nysa.pretty_print_sdb()
    d = nysa.find_device(ArtemisPCIEDriver)[0]
    #driver = ArtemisPCIEDriver(nysa, nysa.find_device(ArtemisPCIEDriver)[0])
    driver = yield cocotb.external(ArtemisPCIEDriver)(nysa, d)
    c = CocotbPCIE(dut, debug = False)

    ADDRESS     = 0x00

    idword      = 0xCD15DBE5
    command     = 0x00000001
    data_count  = 0x00000001
    address     = 0x01000000
    d           = 0x01234567

    data = Array('B')
    data.extend(convert_dword_to_byte_array(0x0000000))
    data.extend(convert_dword_to_byte_array(idword))
    data.extend(convert_dword_to_byte_array(command))
    data.extend(convert_dword_to_byte_array(data_count))
    data.extend(convert_dword_to_byte_array(address))
    data.extend(convert_dword_to_byte_array(d))

    v = yield cocotb.external(driver.get_control)()

    c.configure_FPGA()
    cocotb.log.info("Reduce the block size to 0x400")
    c.set_dword_buffer_size(0x0200)

    yield (nysa.wait_clocks(50))
    yield c.write_pcie_data(ADDRESS, data)
    yield (nysa.wait_clocks(400))


