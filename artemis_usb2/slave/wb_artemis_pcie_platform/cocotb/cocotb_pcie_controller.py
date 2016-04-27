import os
import sys
from array import array as Array


import cocotb
import threading
from cocotb.triggers import Timer
from cocotb.triggers import Join
from cocotb.triggers import RisingEdge
from cocotb.triggers import ReadOnly
from cocotb.triggers import FallingEdge
from cocotb.triggers import ReadWrite
from cocotb.triggers import Event

from cocotb.result import ReturnValue
from cocotb.result import TestFailure
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb import bus
import json
from collections import OrderedDict
import cocotb.monitors

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, "tools")))
from tlp_manager import TLPManager

from cocotb_axi_bus import AXIStreamMaster
from cocotb_axi_bus import AXIStreamSlave

from nysa.common.print_utils import *


NAME="PCIE Controller"

#Register Values
REG_STATUS_BUF_ADDR       = 0x00
REG_BUFFER_READY          = 0x01
REG_WRITE_BUF_A_ADDR      = 0x02
REG_WRITE_BUF_B_ADDR      = 0x03
REG_READ_BUF_A_ADDR       = 0x04
REG_READ_BUF_B_ADDR       = 0x05
REG_BUFFER_SIZE           = 0x06
REG_PING_VALUE            = 0x07
REG_ADDR_VALUE            = 0x08

#Commands
CMD_COMMAND_RESET         = 0x0080
CMD_PERIPHERAL_WRITE      = 0x0081
CMD_PERIPHERAL_WRITE_FIFO = 0x0082
CMD_PERIPHERAL_READ       = 0x0083
CMD_PERIPHERAL_READ_FIFO  = 0x0084
CMD_MEMORY_WRITE          = 0x0085
CMD_MEMORY_READ           = 0x0086
CMD_DMA_WRITE             = 0x0087
CMD_DMA_READ              = 0x0088
CMD_PING                  = 0x0089
CMD_READ_CONFIG           = 0x008A



BAR0_ADDR               = 0x00000000
STATUS_BUFFER_ADDRESS   = 0x01000000
WRITE_BUFFER_A_ADDRESS  = 0x02000000
WRITE_BUFFER_B_ADDRESS  = 0x03000000
READ_BUFFER_A_ADDRESS   = 0x04000000
READ_BUFFER_B_ADDRESS   = 0x05000000
BUFFER_SIZE             = 0x00000800

def dword_to_array(value):
    out = Array('B')
    out.append((value >> 24) & 0xFF)
    out.append((value >> 16) & 0xFF)
    out.append((value >>  8) & 0xFF)
    out.append((value >>  0) & 0xFF)
    return out

class CocotbPCIE (object):

    def __init__(self, dut, debug = False):
        self.debug = debug
        self.dut = dut
        self.clk = dut.clk
        self.busy_event = Event("%s_busy" % NAME)
        self.axm = AXIStreamMaster(self.dut.s1.api.pcie_interface, 'm_axis_rx', self.dut.s1.api.pcie_interface.clk)
        self.axs = AXIStreamSlave (self.dut.s1.api.pcie_interface, 's_axis_tx', self.dut.s1.api.pcie_interface.clk)
        self.tm = TLPManager()
        self.w = None
        self.r = None
        self.base_address = 0x0200

    def set_base_address(self, base_address):
        self.base_address = base_address

    def configure_FPGA(self):
        self.set_status_buf_addr(STATUS_BUFFER_ADDRESS)
        self.set_buffer_ready_status(0x00)
        self.set_write_buf_a_addr(WRITE_BUFFER_A_ADDRESS)
        self.set_write_buf_b_addr(WRITE_BUFFER_B_ADDRESS)
        self.set_read_buf_a_addr(READ_BUFFER_A_ADDRESS)
        self.set_read_buf_b_addr(READ_BUFFER_B_ADDRESS)
        self.set_buffer_size(BUFFER_SIZE)
        self.set_dev_addr(0x00)

    @cocotb.coroutine
    def _acquire_lock(self):
        if self.busy:
            yield self.busy_event.wait()
        self.busy_event.clear()
        self.busy = True

    def _release_lock(self):
        self.busy = False
        self.busy_event.set()

    @cocotb.coroutine
    def main_control(self):
        cocotb.log.info("Entered PCIE Control Loop")
        yield RisingEdge(self.dut.clk)
        cocotb.log.info("Detected Rising Edge of clock")

    @cocotb.coroutine
    def send_PCIE_command(self, data):
        #yield RisingEdge(self.dut.clk)
        #cocotb.log.info("Sending command to memory")
        yield self.axm.write(data)

    @cocotb.coroutine
    def listen_for_comm(self, wait_for_ready = False):
        cocotb.log.info("Listen for comm")
        yield self.axs.read_packet(wait_for_ready)

    def get_read_data(self):
        return self.axs.get_data()

    def reset_data(self):
        self.axs.reset_data()

    def write_register(self, address, data):
        #Convert Word address to byte address
        address = self.base_address + (address << 2)
        print "Address: 0x%08X" % address
        #address = address << 2
        #if self.debug: cocotb.log.info("Entered Write Register")
        self.tm.set_value("type", "mwr")
        self.tm.set_value("address", address)
        self.tm.set_value("dword_count", 1)
        data_out = self.tm.generate_raw()
        data_out.append((data >> 24) & 0xFF)
        data_out.append((data >> 16) & 0xFF)
        data_out.append((data >>  8) & 0xFF)
        data_out.append((data >>  0) & 0xFF)
        if self.debug: print_32bit_hex_array(data_out)
        self.w = cocotb.fork(self.send_PCIE_command(data_out))
        if self.w:
            self.w.join()

    def set_status_buf_addr(self, addr):
        self.write_register(REG_STATUS_BUF_ADDR, addr)

    def set_buffer_ready_status(self, ready_status):
        self.write_register(REG_BUFFER_READY, ready_status)

    def set_write_buf_a_addr(self, addr):
        self.write_register(REG_WRITE_BUF_A_ADDR, addr)

    def set_write_buf_b_addr(self, addr):
        self.write_register(REG_WRITE_BUF_B_ADDR, addr)

    def set_read_buf_a_addr(self, addr):
        self.write_register(REG_READ_BUF_A_ADDR, addr)

    def set_read_buf_b_addr(self, addr):
        self.write_register(REG_READ_BUF_B_ADDR, addr)

    def set_buffer_size(self, buf_size):
        self.write_register(REG_BUFFER_SIZE, buf_size)

    def set_dev_addr(self, address):
        self.write_register(REG_ADDR_VALUE, address)

    def write_command(self, command, count = 0, address = 0):
        #Convert Word address to byte address
        #command += self.base_address
        #command = command << 2
        command = self.base_address + (command << 2)
        print "Command: 0x%08X" % command
        self.tm.set_value("type", "mwr")
        self.tm.set_value("address", command)
        self.tm.set_value("dword_count", 2)
        data_out = self.tm.generate_raw()
        data_out.extend(dword_to_array(count))
        data_out.extend(dword_to_array(address))
        if self.debug: print_32bit_hex_array(data_out)
        self.w = cocotb.fork(self.send_PCIE_command(data_out))
        if self.w:
            self.w.join()

    @cocotb.coroutine
    def read_config_regs(self, wait_for_ready = False):
        #Read a the response, the status register should have the data
        self.write_command(CMD_READ_CONFIG, count = 0, address = 0x01)
        yield self.listen_for_comm(wait_for_ready)
        data = self.get_read_data()

        #print "Raw 32-bit value:"
        #print_32bit_hex_array(data)
        self.tm.parse_raw(data)
        self.tm.pretty_print()

    @cocotb.coroutine
    def read_pcie_data_command(self, count, address):
        self.write_command(CMD_PERIPHERAL_READ, count, address);
        yield RisingEdge(self.dut.clk)

        #self.tm.parse_raw(data)
        #self.tm.pretty_print()

    @cocotb.coroutine
    def wait_for_data(self, wait_for_ready = False):
        self.reset_data()
        yield self.listen_for_comm(wait_for_ready)
        data = self.get_read_data()
        self.tm.parse_raw(data)
        self.tm.pretty_print()


