import os
import sys
from array import array as Array

import cocotb
from cocotb import log
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

from riffa_fifo_bus import RIFFAIngress
from riffa_fifo_bus import RIFFAEgress

NAME = "CocotbRIFFA"

FLAG_MEM_BUS                = 0x0001
FLAG_DISABLE_AUTO_INC       = 0x0002
FLAG_DMA_BUS                = 0x0004
FLAG_MEM_DMA_R              = 0x0008

COMMAND_PING                = 0x0000
COMMAND_WRITE               = 0x0001
COMMAND_READ                = 0x0002
COMMAND_RESET               = 0x0003
COMMAND_MASTER_ADDR         = 0x0004


PERIPHERAL_CHANNEL          = 0
MEMORY_CHANNEL              = 1
DMA_CHANNEL                 = 2


def dword_to_bytes(din):
    dout = Array('B')
    dout.append((din >> 24) & 0xFF)
    dout.append((din >> 16) & 0xFF)
    dout.append((din >>  8) & 0xFF)
    dout.append((din >>  0) & 0xFF)
    return dout

class CocotbRIFFA(object):

    def __init__(self, dut, ingress_path, ingress_clk, egress_path, egress_clk, debug = False):
        self.dut = dut
        self.clk = dut.clk
        self.busy_event = Event("%s_busy" % NAME)
        self.ringress = RIFFAIngress(ingress_path, "riffa", ingress_clk)
        self.regress  = RIFFAEgress (egress_path,  "riffa",  egress_clk)
        self.data = Array('B')

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
    def get_data(self):
        return self.data

    @cocotb.coroutine
    def write_peripheral(self, address, data, auto_inc = True):
        #Generate the command, data count and address
        flags = 0
        if not auto_inc:
            flags |= FLAG_DISABLE_AUTO_INC

        command = COMMAND_WRITE
        command |= flags << 16

        while (len(data) % 4) > 0:
            data.append(0x00)

        data_count = len(data) / 4
        log.info("Data Count: %d" % data_count)
        

        #Construct the packet
        packet_data = Array('B')
        packet_data.extend(dword_to_bytes(command))
        packet_data.extend(dword_to_bytes(data_count))
        packet_data.extend(dword_to_bytes(address))
        packet_data.extend(data)
        yield (self.ringress.write(packet_data, PERIPHERAL_CHANNEL))

    @cocotb.coroutine
    def write_memory(self, address, data):
        #Peripheral is on channel 1

        #First configure the write using the preipheral bus
        #Peripheral is on channel 0
        #Generate the command, data count and address
        flags = FLAG_MEM_BUS
        command = COMMAND_WRITE
        command |= flags << 16

        while (len(data) % 4) > 0:
            data.append(0x00)

        data_count = len(data) / 4

        #Construct the packet
        packet_data = Array('B')
        packet_data.extend(dword_to_bytes(command))
        packet_data.extend(dword_to_bytes(data_count))
        packet_data.extend(dword_to_bytes(address))
        #packet_data.extend(data)

        yield (self.ringress.write(packet_data, PERIPHERAL_CHANNEL))

        packet_data = Array('B')
        packet_data.extend(data)
        yield (self.ringress.write(packet_data, MEMORY_CHANNEL))

    @cocotb.coroutine
    def write_dma(self, address, data):
        #Peripheral is on channel 1

        #First configure the write using the preipheral bus
        #Peripheral is on channel 0
        #Generate the command, data count and address
        flags = FLAG_DMA_BUS
        command = COMMAND_WRITE
        command |= flags << 16

        while (len(data) % 4) > 0:
            data.append(0x00)

        data_count = len(data) / 4

        #Construct the packet
        packet_data = Array('B')
        packet_data.extend(dword_to_bytes(command))
        packet_data.extend(dword_to_bytes(data_count))
        packet_data.extend(dword_to_bytes(address))
        #packet_data.extend(data)

        yield (self.ringress.write(packet_data, PERIPHERAL_CHANNEL))

        packet_data = Array('B')
        packet_data.extend(data)
        yield (self.ringress.write(packet_data, DMA_CHANNEL))

    @cocotb.coroutine
    def read_peripheral(self, address, data_count, auto_inc = True):
        #Generate the command, data count and address
        flags = 0
        if not auto_inc:
            flags |= FLAG_DISABLE_AUTO_INC

        command = COMMAND_READ
        command |= flags << 16

        log.info("Data Count: %d" % data_count)

        #Construct the packet
        packet_data = Array('B')
        packet_data.extend(dword_to_bytes(command))
        packet_data.extend(dword_to_bytes(data_count))
        packet_data.extend(dword_to_bytes(address))
        #packet_data.extend(data)
        yield (self.ringress.write(packet_data, PERIPHERAL_CHANNEL))
        yield (self.regress.read())

    def get_read_data(self):
        return self.regress.get_data()

    @cocotb.coroutine
    def read_memory(self, address, data_count):
        #Generate the command, data count and address
        flags = 0
        flags |= FLAG_MEM_BUS
        flags |= FLAG_MEM_DMA_R

        command = COMMAND_WRITE
        command |= flags << 16

        log.info("Data Count: %d" % data_count)

        #Construct the packet
        packet_data = Array('B')
        packet_data.extend(dword_to_bytes(command))
        packet_data.extend(dword_to_bytes(data_count))
        packet_data.extend(dword_to_bytes(address))
        #packet_data.extend(data)
        #Send the request on the peripheral bus, this will then tell the
        # Host interface to write data to the host computer
        yield (self.ringress.write(packet_data, PERIPHERAL_CHANNEL))
        yield (self.regress.read())

    @cocotb.coroutine
    def read_dma(self, address, data_count):
        #Generate the command, data count and address
        flags = 0
        flags |= FLAG_DMA_BUS
        flags |= FLAG_MEM_DMA_R

        command = COMMAND_WRITE
        command |= flags << 16

        log.info("Data Count: %d" % data_count)

        #Construct the packet
        packet_data = Array('B')
        packet_data.extend(dword_to_bytes(command))
        packet_data.extend(dword_to_bytes(data_count))
        packet_data.extend(dword_to_bytes(address))
        #packet_data.extend(data)
        #Send the request on the peripheral bus, this will then tell the
        # Host interface to write data to the host computer
        yield (self.ringress.write(packet_data, PERIPHERAL_CHANNEL))
        yield (self.regress.read())

    @cocotb.coroutine
    def read_dma_with_delay(self, address, data_count, delay_count, delay_timeout):
        #Generate the command, data count and address
        flags = 0
        flags |= FLAG_DMA_BUS
        flags |= FLAG_MEM_DMA_R

        command = COMMAND_WRITE
        command |= flags << 16

        log.info("Data Count: %d" % data_count)

        #Construct the packet
        packet_data = Array('B')
        packet_data.extend(dword_to_bytes(command))
        packet_data.extend(dword_to_bytes(data_count))
        packet_data.extend(dword_to_bytes(address))
        #packet_data.extend(data)
        #Send the request on the peripheral bus, this will then tell the
        # Host interface to write data to the host computer
        yield (self.ringress.write(packet_data, PERIPHERAL_CHANNEL))
        yield (self.regress.read_with_delay(delay_count, delay_timeout))

    @cocotb.coroutine
    def ping(self):
        pass





