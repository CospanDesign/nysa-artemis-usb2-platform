import logging
import cocotb
from cocotb.triggers import RisingEdge, ReadOnly, Lock
from cocotb.drivers import BusDriver
from cocotb.result import ReturnValue
from cocotb.binary import BinaryValue
from cocotb import log

import binascii
from array import array as Array

def create_32bit_word(data_array, index):
    return (data_array[index] << 24) | (data_array[index + 1] << 16) | (data_array[index + 2] << 8) | (data_array[index + 3])


class RIFFAIngress(BusDriver):

    _signals = ["channel", "enable", "ack", "last", "len", "off", "data", "data_valid", "data_ren"]  # Write data channel

    def __init__(self, entity, name, clock, debug = False):
        BusDriver.__init__(self, entity, name, clock)
        self.debug = debug
        if debug:
            self.log.setLevel(logging.DEBUG)

        #Driver Default Value onto the bus
        self.bus.channel    <= 0
        self.bus.enable     <= 0
        self.bus.last       <= 0
        self.bus.len        <= 0
        self.bus.off        <= 0
        self.bus.data_valid <= 0
        self.bus.data       <= 0

        self.write_data_busy = Lock("%s_wbusy" % name)

    @cocotb.coroutine
    def write(self, data, channel = 0, offset = 0):
        """
        Send the write data
        """
        while len(data) % 4 != 0:
            data.append(0x00)

        yield self.write_data_busy.acquire()

        self.bus.channel    <= channel
        self.bus.data_valid <= 0
        self.bus.enable     <= 1
        self.bus.last       <= 1
        self.bus.len        <= len(data) / 4
        self.bus.off        <= offset
        #self.bus.data       <= create_32bit_word(data, 0)
        self.bus.data       <= 0x00

        yield RisingEdge(self.clock)
        log.info("Sending: %d bytes, %d dwords" % (len(data), len(data) / 4))
        log.info("Waiting for Ack")
        yield RisingEdge(self.bus.ack)
        log.info("Ack Detected")
        yield RisingEdge(self.clock)

        for i in range(0, len(data), 4):
            self.bus.data       <=  create_32bit_word(data, i)
            log.info("Writing data value [%02d] (i / 4 = [%02d]): 0x%08X" % (i, i / 4, create_32bit_word(data, i)))
            self.bus.data_valid <=  1
            yield ReadOnly()
            if self.bus.data_ren.value:
                yield RisingEdge(self.clock)

            else:
                while not self.bus.data_ren.value:
                    #log.info("Wating...")
                    yield RisingEdge(self.clock)



        self.bus.data_valid <= 0
        self.bus.enable     <= 0
        self.bus.last       <= 0
        self.bus.len        <= 0
        self.bus.off        <= 0
        log.info("Finished")
        yield RisingEdge(self.clock)
        self.write_data_busy.release()

class RIFFAEgress(BusDriver):

    _signals = ["enable", "ack", "last", "len", "off", "data", "data_valid", "data_ren"]  # Write data channel

    def __init__(self, entity, name, clock, debug = False):
        BusDriver.__init__(self, entity, name, clock)
        self.debug = debug

        #Driver Default Value onto the bus
        self.bus.ack        <= 0
        self.bus.data_ren   <= 0
        self.data = Array('B')

        self.read_data_busy = Lock("%s_wbusy" % name)

    def get_data(self):
        return self.data

    def word_to_array(self, data):
        d = Array('B')
        d.append((data >> 24) & 0xFF)
        d.append((data >> 16) & 0xFF)
        d.append((data >>  8) & 0xFF)
        d.append((data >>  0) & 0xFF)
        return d

    @cocotb.coroutine
    def read(self):
        log.info("Attempt to get read lock")

        yield self.read_data_busy.acquire()
        yield RisingEdge(self.clock)
        count = 0

        #Wait for enable signal
        yield RisingEdge(self.bus.enable)
        log.info("Enable went high")
        yield RisingEdge(self.clock)
        self.bus.ack       <=  1
        yield RisingEdge(self.clock)
        self.bus.ack       <=  0


        log.info("Length: %d" % self.bus.len.value)
        while count < self.bus.len.value:
            if self.bus.data_valid.value and self.bus.data_ren.value:
                #log.info("Count: %d" % count)
                self.data.extend(self.word_to_array(self.bus.data.value))
                count   += 1
            yield RisingEdge(self.clock)
            self.bus.data_ren   <=  1

        self.bus.data_ren            <=  0

        #Finished
        self.read_data_busy.release()

    @cocotb.coroutine
    def read_with_delay(self, delay_length, delay_timeout):
        log.info("Attempt to get read lock")

        yield self.read_data_busy.acquire()
        yield RisingEdge(self.clock)
        count = 0
        delay_count = 0
        delay_timeout_count = 0

        #Wait for enable signal
        yield RisingEdge(self.bus.enable)
        log.info("Enable went high")
        yield RisingEdge(self.clock)
        self.bus.ack       <=  1
        yield RisingEdge(self.clock)
        self.bus.ack       <=  0


        log.info("Length: %d" % self.bus.len.value)
        while count < self.bus.len.value:
            if self.bus.data_valid.value and self.bus.data_ren.value:
                #log.info("Count: %d" % count)
                self.data.extend(self.word_to_array(self.bus.data.value))
                count   += 1
                delay_count += 1

            yield RisingEdge(self.clock)
            if delay_count < delay_length:
                self.bus.data_ren   <=  1
            else:
                if delay_timeout_count < delay_timeout:
                    delay_timeout_count += 1
                else:
                    delay_timeout_count = 0
                    delay_count = 0
                self.bus.data_ren   <=  0


        self.bus.data_ren            <=  0

        #Finished
        self.read_data_busy.release()


