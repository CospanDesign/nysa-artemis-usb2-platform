#PUT LICENCE HERE!

"""
ArtemisPCIE Driver

"""

import sys
import os
import time
from array import array as Array

sys.path.append(os.path.join(os.path.dirname(__file__),
                             os.pardir))
from nysa.host.driver import driver

#Sub Module ID
#Use 'nysa devices' to get a list of different available devices
DEVICE_TYPE             = "Experiment"
SDB_ABI_VERSION_MINOR   = 0
SDB_VENDOR_ID           = 0

try:
    SDB_ABI_VERSION_MINOR   = 0
    SDB_VENDOR_ID           = 0x800000000000C594
except SyntaxError:
    pass

#Register Constants
CONTROL                         = 00
STATUS                          = 01
NUM_BLOCK_READ                  = 02
LOCAL_BUFFER_SIZE               = 03




CTRL_BIT_ENABLE                 =   0
CTRL_BIT_SEND_CONTROL_BLOCK     =   1
CTRL_BIT_CANCEL_SEND_BLOCK      =   2
CTRL_BIT_ENABLE_LOCAL_READ      =   3

STS_BIT_PCIE_RESET              =   0
STS_BIT_LINKUP                  =   1
STS_BIT_RECEIVED_HOT_RESET      =   2
STS_BITS_PCIE_LINK_STATE_LOW    =   4
STS_BITS_PCIE_LINK_STATE_HIGH   =   6
STS_BITS_PCIE_BUS_NUM_LOW       =   8
STS_BITS_PCIE_BUS_NUM_HIGH      =   15
STS_BITS_PCIE_DEV_NUM_LOW       =   16
STS_BITS_PCIE_DEV_NUM_HIGH      =   19
STS_BITS_PCIE_FUNC_NUM_LOW      =   20
STS_BITS_PCIE_FUNC_NUM_HIGH     =   22
STS_BIT_LOCAL_MEM_IDLE          =   24

LOCAL_BUFFER_OFFSET             =   0x100


class ArtemisPCIEDriver(driver.Driver):

    """ ArtemisPCIE

        Communication with a DutDriver ArtemisPCIE Core
    """
    @staticmethod
    def get_abi_class():
        return 0

    @staticmethod
    def get_abi_major():
        return driver.get_device_id_from_name(DEVICE_TYPE)

    @staticmethod
    def get_abi_minor():
        return SDB_ABI_VERSION_MINOR

    @staticmethod
    def get_vendor_id():
        return SDB_VENDOR_ID

    def __init__(self, nysa, urn, debug = False):
        super(ArtemisPCIEDriver, self).__init__(nysa, urn, debug)
        self.buffer_size = self.get_local_buffer_size()

    def set_control(self, control):
        self.write_register(CONTROL, control)

    def get_control(self):
        return self.read_register(CONTROL)

    def enable(self, enable):
        self.enable_register_bit(CONTROL, CTRL_BIT_ENABLE, enable)

    def is_enabled(self):
        return self.is_register_bit_set(CONTROL, CTRL_BIT_ENABLE)

    def enable_pcie_read_block(self, enable):
        self.enable_register_bit(CONTROL, CTRL_BIT_ENABLE_LOCAL_READ, enable)

    def is_pcie_read_block_enabled(self):
        return self.is_register_bit_set(CONTROL, CTRL_BIT_ENABLE_LOCAL_READ)

    def send_block_from_local_buffer(self):
        self.set_register_bit(CONTROL, CTRL_BIT_SEND_CONTROL_BLOCK)

    def cancel_block_send_from_local_buffer(self):
        self.set_register_bit(CONTORL, CTRL_BIT_CANCEL_SEND_BLOCK)

    def get_status(self):
        return self.read_register(STATUS)

    def is_pcie_reset(self):
        return self.is_register_bit_set(STATUS, STS_BIT_PCIE_RESET)

    def is_linkup(self):
        return self.is_register_bit_set(STATUS, STS_BIT_LINKUP)

    def is_hot_reset(self):
        return self.is_register_bit_set(STATUS, STS_BIT_RECEIVED_HOT_RESET)

    def get_link_state(self):
        return self.read_register_bit_range(STATUS, STS_BITS_PCIE_LINK_STATE_HIGH, STS_BITS_PCIE_LINK_STATE_LOW)

    def get_link_state_string(self, local_print = False):
        state = self.get_link_state()
        status = ""
        if state == 6:
            status = "Link State: L0"
        elif state == 5:
            status = "Link State: L0s"
        elif state == 3:
            status =  "Link State: L1"
        elif state == 7:
            stats = "Link state: In Transaciton"
        else:
            status = "Link State Unkown: 0x%02X" % state

        if local_print:
            print (status)

        return status

    def get_bus_num(self):
        return self.read_register_bit_range(STATUS, STS_BITS_PCIE_BUS_NUM_HIGH, STS_BITS_PCIE_BUS_NUM_LOW)

    def get_dev_num(self):
        return self.read_register_bit_range(STATUS, STS_BITS_PCIE_DEV_NUM_HIGH, STS_BITS_PCIE_DEV_NUM_LOW)

    def get_func_num(self):
        return self.read_register_bit_range(STATUS, STS_BITS_PCIE_FUNC_NUM_HIGH, STS_BITS_PCIE_FUNC_NUM_LOW)

    def is_local_mem_idle(self):
        return self.is_register_bit_set(STATUS, STS_BIT_LOCAL_MEM_IDLE)

    def get_local_buffer_size(self):
        return self.read_register(LOCAL_BUFFER_SIZE)

    def read_local_buffer(self, address = 0x00, size = None):
        """
        Read the local buffer within the core, if no size is specified
        read the entire buffer,
        if no address is specified read from the beginning

        Args:
            address (Integer): address of data (32-bit aligned) Default 0x00
            size (Integer): Size of read (32-bit words) Default 512

        Returns (Array of Bytes):
            Returns the data as an array of bytes

        Raises:
            Nothing
        """
        if size is None:
            size = self.buffer_size / 4
        return self.read(address + (LOCAL_BUFFER_OFFSET), length = size)

    def write_local_buffer(self, data, address = 0x00):
        """
        Write data to the local buffer that be used to send to the Hard Drive
        By Default the address is set to 0x00

        Args:
            data (Array of bytes): data
            address (Integer): Address within local buffer 0 - 511 (Default 0)

        Returns:
            Nothing

        Raises:
            Nothing
        """
        self.write(address + (LOCAL_BUFFER_OFFSET), data)


