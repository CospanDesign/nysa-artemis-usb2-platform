#! /usr/bin/env python

# Copyright (c) 2016 Dave McCoy (dave.mccoy@cospandesign.com)
#
# NAME is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# NAME is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NAME; If not, see <http://www.gnu.org/licenses/>.


import sys
import os
import argparse
from array import array as Array
from collections import OrderedDict
from nysa.common.print_utils import *
import datetime

#sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

NAME = os.path.basename(os.path.realpath(__file__))

DESCRIPTION = "\n" \
              "\n" \
              "usage: %s [options]\n" % NAME

EPILOG = "\n" \
         "\n" \
         "Examples:\n" \
         "\tSomething\n" \
         "\n"


IDWORD                      = 0xCD15DBE5

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

MAX_PACKET_SIZE             = 0x40

#Register Values
HDR_STATUS_BUF_ADDR       = "status_buf"
HDR_BUFFER_READY          = "hst_buffer_rdy"
HDR_WRITE_BUF_A_ADDR      = "write_buffer_a"
HDR_WRITE_BUF_B_ADDR      = "write_buffer_b"
HDR_READ_BUF_A_ADDR       = "read_buffer_a"
HDR_READ_BUF_B_ADDR       = "read_buffer_b"
HDR_BUFFER_SIZE           = "dword_buffer_size"
HDR_INDEX_VALUEA          = "index value a"
HDR_INDEX_VALUEB          = "index value b"
HDR_DEV_ADDR              = "device_addr"
STS_DEV_STATUS            = "device_status"
STS_BUF_RDY               = "dev_buffer_rdy"
STS_BUF_POS               = "hst_buf_addr"
STS_INTERRUPT             = "interrupt"
HDR_AUX_BUFFER_READY      = "hst_buffer_rdy"

REGISTERS = OrderedDict([
    (HDR_STATUS_BUF_ADDR  , "Address of the Status Buffer on host computer" ),
    (HDR_BUFFER_READY     , "Buffer Ready (Controlled by host)"             ),
    (HDR_WRITE_BUF_A_ADDR , "Address of Write Buffer 0 on host computer"    ),
    (HDR_WRITE_BUF_B_ADDR , "Address of Write Buffer 1 on host computer"    ),
    (HDR_READ_BUF_A_ADDR  , "Address of Read Buffer 0 on host computer"     ),
    (HDR_READ_BUF_B_ADDR  , "Address of Read Buffer 1 on host computer"     ),
    (HDR_BUFFER_SIZE      , "Size of the buffer on host computer"           ),
    (HDR_INDEX_VALUEA     , "Value of Index A"                              ),
    (HDR_INDEX_VALUEB     , "Value of Index B"                              ),
    (HDR_DEV_ADDR         , "Address to read from or write to on device"    ),
    (STS_DEV_STATUS       , "Device Status"                                 ),
    (STS_BUF_RDY          , "Buffer Ready Status (Controller from device)"  ),
    (STS_BUF_POS          , "Address on Host"                               ),
    (STS_INTERRUPT        , "Interrupt Status"                              ),
    (HDR_AUX_BUFFER_READY , "Buffer Ready (Controlled by host)"             )
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


def dword_to_array(value):
    out = Array('B')
    out.append((value >> 24) & 0xFF)
    out.append((value >> 16) & 0xFF)
    out.append((value >>  8) & 0xFF)
    out.append((value >>  0) & 0xFF)
    return out

def array_to_dword(a):
    return (a[0] << 24) | (a[1] << 16) | (a[2] << 8) | a[3]


class NysaPCIE (object):

    def __init__(self, path):
        self.f = os.open(path, os.O_RDWR)

    def set_command_mode(self):
        #self.f.seek(0, 2)
        os.lseek(self.f, 0, os.SEEK_END)

    def set_data_mode(self):
        #self.f.seek(0, 0)
        os.lseek(self.f, 0, os.SEEK_SET)

    def set_dev_addr(self, address):
        self.dev_addr = address
        reg = NysaPCIEConfig.get_config_reg(HDR_DEV_ADDR)
        self.write_register(reg, address)

    def write_register(self, address, data):
        d = Array('B')
        d.extend(dword_to_array(address))
        d.extend(dword_to_array(data))
        self.set_command_mode()
        #self.f.write(d)
        os.write(self.f, d)
        self.set_data_mode()

    def write_command(self, command, count, address):
        d = Array('B')
        d.extend(dword_to_array(command))
        d.extend(dword_to_array(count))
        d.extend(dword_to_array(address))
        self.set_command_mode()
        #self.f.write(d)
        os.write(self.f, d)
        self.set_data_mode()

    def write_periph_data(self, address, data):
        d = Array('B')
        while len(data) % 4:
            data.append(0)

        data_count = len(data) / 4 + 4
        d.extend(dword_to_array(IDWORD))
        d.extend(dword_to_array(0x00000001))
        d.extend(dword_to_array(len(data) / 4))
        d.extend(dword_to_array(address))
        d.extend(data)
        print "Packet Size: %d" % data_count
        print "Total Data:"
        print_32bit_hex_array(d)

        self.write_command(CMD_PERIPHERAL_WRITE, data_count, 0x00)
        #self.write_command(CMD_DMA_WRITE, data_count, 0x00)
        #self.f.write(d)
        os.write(self.f, d)

    def read_periph_data(self, address, count):
        d = Array('B')
        data_count = count
        if data_count == 0:
            data_count = 1
        d.extend(dword_to_array(IDWORD))
        d.extend(dword_to_array(0x00000002))
        d.extend(dword_to_array(data_count))
        d.extend(dword_to_array(address))

        self.write_command(CMD_PERIPHERAL_WRITE, len(d) / 4, 0x00)
        os.write(self.f, d)
        self.write_command(CMD_PERIPHERAL_READ, data_count, 0x00)
        print "Send Peripheral Read Command"
        data = Array('B')
        data.fromstring(os.read(self.f, data_count * 4))
        print "Data: %s" % str(data)

    def write_dma_data(self, data):
        while len(data) % 4:
            data.append(0)

        #print "Send: %s" % str(data)

        self.write_command(CMD_DMA_WRITE, len(data) / 4, 0x00)
        os.write(self.f, data)

    def read_dma_data(self, count):
        d = Array('B')
        self.write_command(CMD_DMA_READ, count, 0x00)
        print "Send Peripheral Read Command"
        data = Array('B')
        data.fromstring(os.read(self.f, count * 4))
        print "Data: %s" % str(data)
        print_32bit_hex_array(d)

    def reset(self):
        self.write_command(CMD_COMMAND_RESET, 0x00, 0x00)
        

DEFAULT_PATH = "/dev/nysa_pcie0"
DEFAULT_COUNT = 1
DEFAULT_ADDRESS = 0x01000000

def main(argv):
    #Parse out the commandline arguments
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=DESCRIPTION,
        epilog=EPILOG
    )

    parser.add_argument("-c", "--count",
                        nargs=1,
                        default=["%d" % DEFAULT_COUNT],
                        help="Number of dwords to send/receive (Default: %d)" % DEFAULT_COUNT)

    parser.add_argument("-s", "--send",
                        action="store_true",
                        help="Send data to the device")

    parser.add_argument("-r", "--receive",
                        action="store_true",
                        help="Receive data from the device")

    parser.add_argument("--reset",
                        action="store_true",
                        help="Reset FPGA")

    parser.add_argument("-a", "--address",
                        nargs=1,
                        default=["%s" % DEFAULT_ADDRESS],
                        help="Set the address of the device: %s" % DEFAULT_ADDRESS)

    parser.add_argument("--device",
                        nargs=1,
                        default=["%s" % DEFAULT_PATH],
                        help="Set the path of the device: %s" % DEFAULT_PATH)

    parser.add_argument("--dma",
                        action="store_true",
                        help="Enable Debug Messages")


    parser.add_argument("-d", "--debug",
                        action="store_true",
                        help="Enable Debug Messages")

    args = parser.parse_args()
    print "Running Script: %s" % NAME

    path = args.device[0]
    address = int(args.address[0], 0)
    count = int(args.count[0], 0)

    write_flag = args.send
    read_flag = args.receive
    reset_flag = args.reset

    n = NysaPCIE(path)

    data = Array('B')
    for i in range(count * 4):
        data.append(i % 256)
    '''
    t = datetime.datetime.now()
    data =  int((t-datetime.datetime(1970,1,1)).total_seconds())
    data = dword_to_array(data)
    '''

    if args.debug:
        print "Path: %s" % path
        print "Address: 0x%08X" % address
        print "Count: %d" % count
        #print "Data: %s" % str(data)
        print "Flags:"
        if write_flag:  print "\tWrite"
        if read_flag:   print "\tRead"
        if reset_flag:  print "\tReset"

    if args.reset:
        print "Reset"
        n.reset()
        
    if not args.dma:
        if write_flag:
            n.write_periph_data(address, data)
        if read_flag:
            n.read_periph_data(address, count)
    else:
        if write_flag:
            print "Write DMA"
            n.write_dma_data(data)
        if read_flag:
            print "Read DMA"
            n.read_dma_data(count)
 

if __name__ == "__main__":
    main(sys.argv)


