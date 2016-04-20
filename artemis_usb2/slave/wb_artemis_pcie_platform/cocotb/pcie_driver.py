import sys
import os
from array import array as Array
import logging
import time


PCIE_NAME = "pcie"

#Registers
class PCIE_REGISTERS(object):
    STATUS_BUF_ADDR       = 0
    BUFFER_READY          = 1
    WRITE_BUF_A_ADDR      = 2
    WRITE_BUF_B_ADDR      = 3
    READ_BUF_A_ADDR       = 4
    READ_BUF_B_ADDR       = 5
    BUFFER_SIZE           = 6
    PING_VALUE            = 7

#Commands
CMD_COMMAND_RESET         = 0x80
CMD_PERIPHERAL_WRITE      = 0x81
CMD_PERIPHERAL_WRITE_FIFO = 0x82
CMD_PERIPHERAL_READ       = 0x83
CMD_PERIPHERAL_READ_FIFO  = 0x84
CMD_MEMORY_WRITE          = 0x85
CMD_MEMORY_READ           = 0x86
CMD_DMA_WRITE             = 0x87
CMD_DMA_READ              = 0x88
CMD_PING                  = 0x89
CMD_READ_CONFIG           = 0x8A


DEFAULT_DEVNAME = "/dev/xpcie"

def convert_32bit_to_array(value):
    data = Array('B')
    data.append((value >> 24) & 0xFF)
    data.append((value >> 16) & 0xFF)
    data.append((value >>  8) & 0xFF)
    data.append((value >>  0) & 0xFF)
    return data

class PCIE (object):

    def __init__(self, filename = DEFAULT_DEVNAME):
        super (PCIE, self).__init__()
        self.pcie = open(DEFAULT_DEVNAME, 'rb+')
        self.l = logging.getLogger(PCIE_NAME)
        self.l.debug("Start PCIE Object")

    def write_register(self, address, value):
        data = convert_32bit_to_array(address)
        data.extend(convert_32bit_to_array(value))
        data.append(0)
        st = data.tostring()
        self.pcie.write(st)
        self.l.debug("Finished write")

    def read_register(self, address, value):
        #Send the command to read all the registers and then just select
        #the register the user has requested
        pass


