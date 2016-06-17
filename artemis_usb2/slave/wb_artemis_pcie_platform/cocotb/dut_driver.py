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
CONTROL                         = 0x000
STATUS                          = 0x001
CFG_READ_EXEC                   = 0x002
CFG_SM_STATE                    = 0x003
CTR_SM_STATE                    = 0x004
INGRESS_COUNT                   = 0x005
INGRESS_STATE                   = 0x006
INGRESS_RI_COUNT                = 0x007
INGRESS_CI_COUNT                = 0x008
INGRESS_ADDR                    = 0x009
INGRESS_CMPLT_COUNT             = 0x00A
IH_STATE                        = 0x00B
OH_STATE                        = 0x00C
BRAM_NUM_READS                  = 0x00D
LOCAL_BUFFER_SIZE               = 0x00E
DBG_ID_VALUE                    = 0x00F
DBG_COMMAND_VALUE               = 0x010
DBG_COUNT_VALUE                 = 0x011
DBG_ADDRESS_VALUE               = 0x012

CTRL_BIT_SOURCE_EN              = 0
CTRL_BIT_CANCEL_WRITE           = 1
CTRL_BIT_SINK_EN                = 2



STS_BIT_LINKUP                  =  0
STS_BIT_READ_IDLE               =  1
STS_PER_FIFO_SEL                =  2
STS_MEM_FIFO_SEL                =  3
STS_DMA_FIFO_SEL                =  4
STS_WRITE_EN                    =  5
STS_READ_EN                     =  6




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
        self.buffer_size = None

    def set_control(self, control):
        self.write_register(CONTROL, control)

    def get_control(self):
        return self.read_register(CONTROL)

    def get_config_state(self):
        return self.read_register(CFG_SM_STATE)

    def get_control_state(self):
        return self.read_register(CTR_SM_STATE)

    def get_config_state_read_count(self):
        return self.read_register(CFG_READ_EXEC)

    def get_ingress_state(self):
        return self.read_register(INGRESS_STATE)

    def get_ingress_count(self):
        return self.read_register(INGRESS_COUNT)

    def get_ingress_ri_count(self):
        return self.read_register(INGRESS_RI_COUNT)

    def get_ingress_ci_count(self):
        return self.read_register(INGRESS_CI_COUNT)

    def get_ingress_cmplt_count(self):
        return self.read_register(INGRESS_CMPLT_COUNT)

    def get_ingress_addr(self):
        return self.read_register(INGRESS_ADDR)

    def get_ih_state(self):
        return self.read_register(IH_STATE)

    def get_oh_state(self):
        return self.read_register(OH_STATE)

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
            if self.buffer_size is None:
                self.buffer_size = self.get_local_buffer_size()
            size = self.buffer_size
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

    def get_dbg_id_value(self):
        return self.read_register(DBG_ID_VALUE)

    def get_dbg_command_value(self):
        return self.read_register(DBG_COMMAND_VALUE)

    def get_dbg_count_value(self):
        return self.read_register(DBG_COUNT_VALUE)

    def get_dbg_address_value(self):
        return self.read_register(DBG_ADDRESS_VALUE)

    def is_link_up(self):
        return self.is_register_bit_set(STATUS, STS_BIT_LINKUP)

    def is_read_idle(self):
        return self.is_register_bit_set(STATUS, STS_BIT_READ_IDLE)

    def is_peripheral_bus_selected(self):
        return self.is_register_bit_set(STATUS, STS_PER_FIFO_SEL)

    def is_memory_bus_selected(self):
        return self.is_register_bit_set(STATUS, STS_MEM_FIFO_SEL)

    def is_dma_bus_selected(self):
        return self.is_register_bit_set(STATUS, STS_DMA_FIFO_SEL)

    def generate_dma_data(self):
        self.enable_register_bit(CONTROL, CTRL_BIT_SOURCE_EN, True)

    def is_write_enabled(self):
        return self.is_register_bit_set(STATUS, STS_WRITE_EN)

    def is_read_enabled(self):
        return self.is_register_bit_set(STATUS, STS_READ_EN)







