import os
import sys


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
STATUS_BUF_ADDR       =  0x00
BUFFER_READY          =  0x01
WRITE_BUF_A_ADDR      =  0x02
WRITE_BUF_B_ADDR      =  0x03
READ_BUF_A_ADDR       =  0x04
READ_BUF_B_ADDR       =  0x05
BUFFER_SIZE           =  0x06
PING_VALUE            =  0x07


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
        self.dut.log.info("Entered PCIE Control Loop")
        yield RisingEdge(self.dut.clk)
        self.dut.log.info("Detected Rising Edge of clock")

    @cocotb.coroutine
    def send_PCIE_command(self, data):
        #yield RisingEdge(self.dut.clk)
        #self.dut.log.info("Sending command to memory")
        yield self.axm.write(data)

    @cocotb.coroutine
    def listen_for_comm(self):
        yield self.axs.read_packet()

    def get_read_data(self):
        return self.axs.get_data()

    def write_register(self, address, data):
        address = address << 2
        #if self.debug: self.dut.log.info("Entered Write Register")
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
        self.write_register(STATUS_BUF_ADDR, addr)

    def set_buffer_ready_status(self, ready_status):
        self.write_register(BUFFER_READY, ready_status)

    def set_write_buf_a_addr(self, addr):
        self.write_register(WRITE_BUF_A_ADDR, addr)

    def set_write_buf_b_addr(self, addr):
        self.write_register(WRITE_BUF_B_ADDR, addr)

    def set_read_buf_a_addr(self, addr):
        self.write_register(READ_BUF_A_ADDR, addr)

    def set_read_buf_b_addr(self, addr):
        self.write_register(READ_BUF_B_ADDR, addr)

    def set_buffer_size(self, buf_size):
        self.write_register(BUFFER_SIZE, buf_size)

    def write_command(self, command, count, address):
        pass

