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

from cocotb_axi_bus import AXIStreamMaster
from cocotb_axi_bus import AXIStreamSlave


NAME="PCIE Controller"

class CocotbPCIE (object):

    def __init__(self, dut):
        self.dut = dut
        self.clk = dut.clk
        self.busy_event = Event("%s_busy" % NAME)
        self.axm = AXIStreamMaster(self.dut.s1.api.pcie_interface, 'm_axis_rx', self.dut.s1.api.pcie_interface.clk)
        self.axs = AXIStreamSlave (self.dut.s1.api.pcie_interface, 's_axis_tx', self.dut.s1.api.pcie_interface.clk)


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
        self.dut.log.info("Sending command to memory")
        yield self.axm.write(data)

    @cocotb.coroutine
    def listen_for_comm(self):
        yield self.axs.read_packet()

    def get_read_data(self):
        return self.axs.get_data()


