import cocotb
from cocotb.triggers import RisingEdge, ReadOnly, Lock
from cocotb.drivers import BusDriver
from cocotb.result import ReturnValue
from cocotb.binary import BinaryValue

import binascii
from array import array as Array


def create_32bit_word(data_array, index):
    return (data_array[index] << 24) | (data_array[index + 1] << 16) | (data_array[index + 2] << 8) | (data_array[index + 3])


class AXIStreamMaster(BusDriver):

    _signals = ["tvalid", "tready", "tdata", "tlast", "tkeep"]  # Write data channel

    def __init__(self, entity, name, clock):
        BusDriver.__init__(self, entity, name, clock)

        #Drive default values onto bus
        self.bus.tvalid <= 0
        self.bus.tlast  <= 0;
        self.bus.tdata  <= 0;
        self.bus.tkeep  <= 0;

        self.write_data_busy = Lock("%s_wbusy" % name)


    @cocotb.coroutine
    def write(self, data):
        """
        Send the write data, with optional delay
        """
        yield self.write_data_busy.acquire()
        self.bus.tvalid <=  0
        self.bus.tlast  <=  0
        self.bus.tdata  <= create_32bit_word(data, 0)
        yield RisingEdge(self.clock)

        self.bus.tvalid <=  1
        #In the rare case we are only sending 1 piece of data
        if len(data) == 4:
            self.bus.tlast <= 1

        yield RisingEdge(self.clock)

        #Wait for the slave to assert tready
        while True:
            yield ReadOnly()
            if self.bus.tready.value:
                break
            yield RisingEdge(self.clock)

        #every clock cycle update the data
        for i in range (4, len(data), 4):
            self.bus.tdata  <= create_32bit_word(data, i)
            if ((i + 4) >= len(data)):
                self.bus.tlast  <=  1;
            yield RisingEdge(self.clock)

        self.bus.tlast  <=  0;
        self.bus.tvalid <=  0;
        yield RisingEdge(self.clock)
        self.write_data_busy.release()


class AXIStreamSlave(BusDriver):

    _signals = ["tvalid", "tready", "tdata", "tlast"]

    def __init__(self, entity, name, clock):
        BusDriver.__init__(self, entity, name, clock)

        self.bus.tready <= 0;
        self.read_data_busy = Lock("%s_wbusy" % name)
        self.data = Array('B')

    def get_data(self):
        return self.data

    def word_to_array(self, axi_data):
        d = Array('B')
        d.append((axi_data >> 24) & 0xFF)
        d.append((axi_data >> 16) & 0xFF)
        d.append((axi_data >>  8) & 0xFF)
        d.append((axi_data >>  0) & 0xFF)
        return d

    @cocotb.coroutine
    def read_packet(self, count = 0):
        """Read a packe of data from the Axi Ingress stream"""
        self.read_data_busy.acquire()
        self.bus.tready <= 1

        while True:
            yield ReadOnly()
            if self.bus.tvalid.value:
                break
            yield RisingEdge(self.clock)


        yield RisingEdge(self.clock)
        while self.bus.tvalid:
            self.data.extend(self.word_to_array(self.bus.tdata.value))
            yield RisingEdge(self.clock)


        self.read_data_busy.release()
        self.bus.tready <= 0


