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

#Commands
CMD_COMMAND_RESET           = 0x0080
CMD_PERIPHERAL_WRITE        = 0x0081
CMD_PERIPHERAL_WRITE_FIFO   = 0x0082
CMD_PERIPHERAL_READ         = 0x0083
CMD_PERIPHERAL_READ_FIFO    = 0x0084
CMD_MEMORY_WRITE            = 0x0085
CMD_MEMORY_READ             = 0x0086
CMD_DMA_WRITE               = 0x0087
CMD_DMA_READ                = 0x0088
CMD_PING                    = 0x0089
CMD_READ_CONFIG             = 0x008A

BAR0_ADDR                   = 0x00000000
STATUS_BUFFER_ADDRESS       = 0x01000000
WRITE_BUFFER_A_ADDRESS      = 0x02000000
WRITE_BUFFER_B_ADDRESS      = 0x03000000
READ_BUFFER_A_ADDRESS       = 0x04000000
READ_BUFFER_B_ADDRESS       = 0x05000000
BUFFER_SIZE                 = 0x00000400

MAX_PACKET_SIZE             = 0x80

def dword_to_array(value):
    out = Array('B')
    out.append((value >> 24) & 0xFF)
    out.append((value >> 16) & 0xFF)
    out.append((value >>  8) & 0xFF)
    out.append((value >>  0) & 0xFF)
    return out

def array_to_dword(a):
    return (a[0] << 24) | (a[1] << 16) | (a[2] << 8) | a[3]

#Register Values
HDR_STATUS_BUF_ADDR       = "status_buf"
HDR_BUFFER_READY          = "hst_buffer_rdy"
HDR_WRITE_BUF_A_ADDR      = "write_buffer_a"
HDR_WRITE_BUF_B_ADDR      = "write_buffer_b"
HDR_READ_BUF_A_ADDR       = "read_buffer_a"
HDR_READ_BUF_B_ADDR       = "read_buffer_b"
HDR_BUFFER_SIZE           = "dword_buffer_size"
HDR_PING_VALUE            = "ping value"
HDR_DEV_ADDR              = "device_addr"
STS_DEV_STATUS            = "device_status"
STS_BUF_RDY               = "dev_buffer_rdy"
STS_BUF_POS               = "hst_buf_addr"
STS_INTERRUPT             = "interrupt"

REGISTERS = OrderedDict([
    (HDR_STATUS_BUF_ADDR  , "Address of the Status Buffer on host computer" ),
    (HDR_BUFFER_READY     , "Buffer Ready (Controlled by host)"             ),
    (HDR_WRITE_BUF_A_ADDR , "Address of Write Buffer 0 on host computer"    ),
    (HDR_WRITE_BUF_B_ADDR , "Address of Write Buffer 1 on host computer"    ),
    (HDR_READ_BUF_A_ADDR  , "Address of Read Buffer 0 on host computer"     ),
    (HDR_READ_BUF_B_ADDR  , "Address of Read Buffer 1 on host computer"     ),
    (HDR_BUFFER_SIZE      , "Size of the buffer on host computer"           ),
    (HDR_PING_VALUE       , "Value of Ping command"                         ),
    (HDR_DEV_ADDR         , "Address to read from or write to on device"    ),
    (STS_DEV_STATUS       , "Device Status"                                 ),
    (STS_BUF_RDY          , "Buffer Ready Status (Controller from device)"  ),
    (STS_BUF_POS          , "Address on Host"                               ),
    (STS_INTERRUPT        , "Interrupt Status"                              )
])

SB_READY          = "ready"
SB_WRITE          = "write"
SB_READ           = "read"
SB_FIFO           = "flag_fifo"
SB_PING           = "ping"
SB_READ_CFG       = "read_cfg"
SB_UNKNOWN_CMD    = "unknown_cmd"
SB_PPFIFO_STALL   = "ppfifo_stall"
SB_HOST_BUF_STALL = "host_buf_stall"
SB_PERIPH         = "flag_peripheral"
SB_MEM            = "flag_mem"
SB_DMA            = "flag_dma"
SB_INTERRUPT      = "interrupt"
SB_RESET          = "reset"
SB_DONE           = "done"
SB_CMD_ERR        = "error"

STATUS_BITS = OrderedDict([
    (SB_READY          , "Ready for new commands"      ),
    (SB_WRITE          , "Write Command Enabled"       ),
    (SB_READ           , "Read Command Enabled"        ),
    (SB_FIFO           , "Flag: Read/Write FIFO"       ),
    (SB_PING           , "Ping Command"                ),
    (SB_READ_CFG       , "Read Config Request"         ),
    (SB_UNKNOWN_CMD    , "Unknown Command"             ),
    (SB_PPFIFO_STALL   , "Stall Due to Ping Pong FIFO" ),
    (SB_HOST_BUF_STALL , "Stall Due to Host Buffer"    ),
    (SB_PERIPH         , "Flag: Peripheral Bus"        ),
    (SB_MEM            , "Flag: Memory"                ),
    (SB_DMA            , "Flag: DMA"                   ),
    (SB_INTERRUPT      , "Device Initiated Interrupt"  ),
    (SB_RESET          , "Reset Command"               ),
    (SB_DONE           , "Command Done"                ),
    (SB_CMD_ERR        , "Error executing command"     )
])

class NysaPCIEConfig (object):

    @staticmethod
    def get_config_reg(name):
        if name in REGISTERS.keys():
            return REGISTERS.keys().index(name)

    @staticmethod
    def is_status_packet(tlp, status_buffer_addr):
        return (tlp.get_value("address") == status_buffer_addr)

    def __init__(self, tlp):
        self.tlp = tlp

    def get_value(self, name):
        index = REGISTERS.keys().index(name)
        a = self.tlp.get_value("data")[(index * 4):((index + 1) * 4)]
        return array_to_dword(a)

    def get_status_bit(self, name):
        if name not in STATUS_BITS:
            raise AssertionError("Status Bit: %s Not Found", name)
        status = self.get_value(STS_DEV_STATUS)
        return ((status & 1 << STATUS_BITS.keys().index(name)) > 0)

    def pretty_print(self, tab = 0):
        output_str = "Status Packet\n"
        for r in REGISTERS.keys():
            name = r
            addr = REGISTERS.keys().index(r)
            #value = self.get_value(addr)
            value = self.get_value(name)
            desc = REGISTERS[r]
            output_str += "\t" * (tab + 1)
            output_str += "{0:20}[0x{1:02X}]: 0x{2:08X} : {3}\n".format(name, addr, value, desc)
            if name == STS_DEV_STATUS:
                output_str += "\t" * (tab + 1)
                output_str += "Status Bits:\n"
                for s in STATUS_BITS:
                    bit_name = s
                    bit_index = STATUS_BITS.keys().index(s)
                    bit_value = self.get_status_bit(bit_name)
                    bit_desc = STATUS_BITS[s]
                    output_str += "\t" * (tab + 2)
                    output_str += "{0:15}[0x{1:02X}]: {2:>5} : {3}\n".format(bit_name, bit_index, bit_value, bit_desc)

        return output_str

class CocotbPCIE (object):

    def __init__(self, dut, debug = False):
        self.debug = debug
        self.dut = dut
        self.clk = dut.clk
        self.busy_event = Event("%s_busy" % NAME)
        self.axm = AXIStreamMaster(self.dut.s1.api.pcie_interface, 'm_axis_rx', self.dut.s1.api.pcie_interface.clk)
        self.axs = AXIStreamSlave (self.dut.s1.api.pcie_interface, 's_axis_tx', self.dut.s1.api.pcie_interface.clk)
        self.tm_out = TLPManager()
        self.w = None
        self.r = None
        self.base_address = 0x0200
        self.dword_buffer_size = BUFFER_SIZE
        self.status_addr = STATUS_BUFFER_ADDRESS
        self.write_addr = [WRITE_BUFFER_A_ADDRESS, WRITE_BUFFER_B_ADDRESS]
        self.read_addr = [READ_BUFFER_A_ADDRESS, READ_BUFFER_B_ADDRESS]
        self.dev_addr = 0x00
        self.max_packet_size = MAX_PACKET_SIZE
        self.backthread = None
        self.data_fifo = []

    def finish_background(self):
        self.dut.log.info("Finish Background thread")
        if self.backthread is not None:
            self.backthread.kill()
        self.dut.log.info("Finish Background thread Done!")
        self.backthread = None

    @cocotb.coroutine
    def wait_for_data_background(self):
        self.dut.log.info("Starting background thread")
        self.backthread = cocotb.fork(self.background_read())
        self.dut.log.info("Started")
        yield self.sleep(10)

    @cocotb.coroutine
    def background_read(self):
        self.done = False
        self.data_fifo = []
        while (1):
            #self.dut.log.info("Waiting for data")
            yield self.listen_for_comm()
            #self.dut.log.info("Received data")
            data = self.axs.get_data()
            self.data_fifo.insert(0, data)

    def set_base_address(self, base_address):
        self.base_address = base_address

    def configure_FPGA(self):
        self.set_status_buf_addr(STATUS_BUFFER_ADDRESS)
        self.set_buffer_ready_status(0x00)
        self.set_write_buf_a_addr(WRITE_BUFFER_A_ADDRESS)
        self.set_write_buf_b_addr(WRITE_BUFFER_B_ADDRESS)
        self.set_read_buf_a_addr(READ_BUFFER_A_ADDRESS)
        self.set_read_buf_b_addr(READ_BUFFER_B_ADDRESS)
        self.set_dword_buffer_size(BUFFER_SIZE)
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
        self.tm_out.set_value("type", "mwr")
        self.tm_out.set_value("address", address)
        self.tm_out.set_value("dword_count", 1)
        data_out = self.tm_out.generate_raw()
        data_out.append((data >> 24) & 0xFF)
        data_out.append((data >> 16) & 0xFF)
        data_out.append((data >>  8) & 0xFF)
        data_out.append((data >>  0) & 0xFF)
        if self.debug: print_32bit_hex_array(data_out)
        self.w = cocotb.fork(self.send_PCIE_command(data_out))
        if self.w:
            self.w.join()

    def set_status_buf_addr(self, addr):
        self.status_addr = addr
        reg = NysaPCIEConfig.get_config_reg(HDR_STATUS_BUF_ADDR)
        self.write_register(reg, addr)

    def set_buffer_ready_status(self, ready_status):
        reg = NysaPCIEConfig.get_config_reg(HDR_BUFFER_READY)
        self.write_register(reg, ready_status)

    def set_write_buf_a_addr(self, addr):
        self.write_addr[0] = addr
        reg = NysaPCIEConfig.get_config_reg(HDR_WRITE_BUF_A_ADDR)
        self.write_register(reg, addr)

    def set_write_buf_b_addr(self, addr):
        self.write_addr[1] = addr
        reg = NysaPCIEConfig.get_config_reg(HDR_WRITE_BUF_B_ADDR)
        self.write_register(reg, addr)

    def set_read_buf_a_addr(self, addr):
        self.read_addr[0] = addr
        reg = NysaPCIEConfig.get_config_reg(HDR_READ_BUF_A_ADDR)
        self.write_register(reg, addr)

    def set_read_buf_b_addr(self, addr):
        self.read_addr[1] = addr
        reg = NysaPCIEConfig.get_config_reg(HDR_READ_BUF_B_ADDR)
        self.write_register(reg, addr)

    def set_dword_buffer_size(self, buf_size):
        self.dword_buffer_size = buf_size
        reg = NysaPCIEConfig.get_config_reg(HDR_BUFFER_SIZE)
        self.write_register(reg, buf_size)

    def set_dev_addr(self, address):
        self.dev_addr = address
        reg = NysaPCIEConfig.get_config_reg(HDR_DEV_ADDR)
        self.write_register(reg, address)

    def write_command(self, command, count = 0, address = 0):
        #Convert Word address to byte address
        #command += self.base_address
        #command = command << 2
        self.set_dev_addr(address)
        command = self.base_address + (command << 2)
        print "Command: 0x%08X" % command
        self.tm_out.set_value("type", "mwr")
        self.tm_out.set_value("address", command)
        self.tm_out.set_value("dword_count", 2)
        data_out = self.tm_out.generate_raw()
        data_out.extend(dword_to_array(count))
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
        self.tm_out.parse_raw(data)
        self.tm_out.pretty_print()
        self.data = data

    def get_tlp_data(self):
        return self.data

    @cocotb.coroutine
    def read_pcie_data_command(self, count, address):
        self.write_command(CMD_PERIPHERAL_READ, count, address);
        yield RisingEdge(self.dut.clk)


        #self.tm_out.parse_raw(data)
        #self.tm_out.pretty_print()

    @cocotb.coroutine
    def wait_for_data(self, wait_for_ready = False, print_data = True):
        self.reset_data()
        yield self.listen_for_comm(wait_for_ready)
        data = self.get_read_data()
        self.tm_out.parse_raw(data)
        if print_data:
            self.tm_out.pretty_print()

    @cocotb.coroutine
    def write_pcie_data_command(self, address, count):
        self.write_command(CMD_PERIPHERAL_WRITE, count, address)
        yield RisingEdge(self.dut.clk)

    @cocotb.coroutine
    def sleep(self, value):
        for i in range (value):
            yield RisingEdge(self.dut.clk)
            yield ReadOnly()

    @cocotb.coroutine
    def read_pcie_data(self, address, count):
        yield self.read_pcie_data_command(count, address)
        data = Array('B')
        self.set_buffer_ready_status(0x03)
        while True:
            yield self.sleep(10)
            yield self.wait_for_data(print_data = False)
            #yield self.wait_for_data(print_data = True)
            if NysaPCIEConfig.is_status_packet(self.tm_out, self.status_addr):
                status = NysaPCIEConfig(self.tm_out)
                buf_hst_rdy = status.get_value(HDR_BUFFER_READY)
                #buf_dev_sts = status.get_value(STS_BUF_RDY)
                print status.pretty_print()
                if status.get_status_bit("done"):
                    return
                host_buffer = 0x3 & (~buf_hst_rdy)
                self.set_buffer_ready_status(host_buffer)

        yield self.sleep(10)

    @cocotb.coroutine
    def write_pcie_data(self, address, data):
        count = len(data)
        data_pos = 0
        pos = 0
        data_sent = 0
        byte_length = self.dword_buffer_size << 2
        yield self.write_pcie_data_command(address, (len(data) / 4))
        yield self.sleep(50)

        tag = 0
        requester_id = 0
        address = 0
        data_count = 0
        #buf = [Array('B', [0] * 4096), Array('B', [0] * 4096)]
        buf = [0, 0]

        #yield self.wait_for_data_background()

        while True:
            yield self.sleep(10)
            yield self.wait_for_data(print_data = False)
            print "Data Send: %d Total Count: %d" % (data_sent, count)
            #yield self.wait_for_data(print_data = True)
            #Found Status Buffer
            if NysaPCIEConfig.is_status_packet(self.tm_out, self.status_addr):
                self.dut.log.info("Status Update")
                status = NysaPCIEConfig(self.tm_out)
                #buf_hst_rdy = status.get_value(HDR_BUFFER_READY)
                buf_dev_sts = status.get_value(STS_BUF_RDY)
                print status.pretty_print()
                if status.get_status_bit("done"):
                    return

                #There are buffer available, we can write can prepare more buffers
                host_buffer = 0x3 & buf_dev_sts
                print "Host Buffer Ready: 0x%02X" % host_buffer
                while host_buffer > 0:
                    if host_buffer & 0x01 == 1:
                        bs = 1
                        host_buffer = host_buffer & 0x02
                    else:
                        bs = 2
                        host_buffer = host_buffer & 0x01

                    if data_pos < len(data):
                        length = len(data) - data_pos
                        if length > byte_length:
                            length = byte_length
                        if bs == 1:
                            buf[0] = data[data_pos: data_pos + length]
                        else:
                            buf[1] = data[data_pos: data_pos + length]
                        self.set_buffer_ready_status(bs)
                        data_pos += length
                        print "****Total Size:  %d" % len(data)
                        print "****Buffer Size: %d" % byte_length
                        print "****Data Pos:    %d" % data_pos
                        print "****Length:      %d" % length
                        print "****Position:    %d" % bs
                        yield self.sleep(10)

            elif self.tm_out.get_value("type") == "mrd" and data_sent < count:
                buf_sel = 0
                pos = 0
                tag = self.tm_out.get_value("tag")
                self.dut.log.info("Memory Read: TAG ID: %d" % tag)
                requester_id = self.tm_out.get_value("requester_id")
                address = self.tm_out.get_value("address")
                byte_size = self.tm_out.get_value("dword_count") * 4
                if tag > 7:
                    buf_sel = 1
                address = address - self.write_addr[buf_sel]
                main_buffer = buf[buf_sel]

                print "Prepare to send down: %d bytes" % byte_size
                print "--------------------Address: 0x%08X" % address
                while pos < byte_size:
                    #print "Pos: %d, byte count:  %d" % (pos, byte_size)
                    #print "address: 0x%04X" % address
                    length = byte_size - pos
                    if length > MAX_PACKET_SIZE:
                        length = MAX_PACKET_SIZE
                    pos += length
                    #print "Length of main buffer: %d" % len(main_buffer)

                    pkt_data = main_buffer[address: address + length]
                    #print "Max Packet Size: %d" % MAX_PACKET_SIZE
                    #print "Length to send: %d, current packet length: %d" % (length, len(pkt_data))
                    #if len(pkt_data) < MAX_PACKET_SIZE:
                    #    print "\tNeed to pad data to %d" % MAX_PACKET_SIZE
                     
                    while len(pkt_data) < MAX_PACKET_SIZE:
                        pkt_data.append(0x00)
                    address += length
                    lower_addr = length
                    #print "Data: %s" % data
                    #lower_addr = address % MAX_PACKET_SIZE
                    byte_count = (byte_size - pos)
                    #print "Byte Count: %d" % byte_count
                    self.tm_out.initialize("cpld")
                    self.tm_out.set_value("tag", tag)
                    self.tm_out.set_value("completer_id", requester_id)
                    self.tm_out.set_value("requester_id", 0x00)
                    self.tm_out.set_value("lower_address", lower_addr)
                    self.tm_out.set_value("dword_count", (MAX_PACKET_SIZE / 4))
                    self.tm_out.set_value("byte_count", byte_count)
                    self.tm_out.set_value("complete_status", 0x00)
                    self.tm_out.set_value("data", pkt_data)
                    self.tm_out.set_value("address", 0x00)
                    data_out = self.tm_out.generate_raw()
                    data_out.extend(pkt_data)

                    #print_32bit_hex_array(data_out)
                    self.w = cocotb.fork(self.send_PCIE_command(data_out))
                    if self.w:
                        self.w.join()
                    yield self.sleep(50)
                    #data_sent += (byte_count / 4)
                    data_sent += byte_size / 4
                    #print "Lower Address: 0x%04X" % lower_addr
                    #print "data_sent: %d, byte count:  %d count: %d" % (pos, byte_size, count)


                #data_count = self.tm_out.get_value(
                #Need to construct a completion packet
        #self.finish_background()
        print "Finished"







