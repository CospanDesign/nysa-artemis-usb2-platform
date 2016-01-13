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
CONTROL                         =   0
STATUS                          =   1
NUM_BLOCK_READ                  =   2
LOCAL_BUFFER_SIZE               =   3
PCIE_CLOCK_CNT                  =   4
TEST_CLOCK                      =   5
TX_DIFF_CTRL                    =   6
RX_EQUALIZER_CTRL               =   7
LTSSM_STATE                     =   8
DBG_DATA                        =   9
CONFIG_COMMAND                  =   10
CONFIG_STATUS                   =   11
CONFIG_DCOMMAND                 =   12
CONFIG_DSTATUS                  =   13
CONFIG_LCOMMAND                 =   14
CONFIG_LSTATUS                  =   15
DBG_FLAGS                       =   16



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
STS_BIT_GTP_PLL_LOCK_DETECT     =   25
STS_BIT_PLL_LOCK_DETECT         =   26
STS_BIT_GTP_RESET_DONE          =   27
STS_BIT_RX_ELEC_IDLE            =   28
STS_BIT_CFG_TO_TURNOFF          =   29


DBG_CORRECTABLE                 =   0
DBG_FATAL                       =   1
DBG_NON_FATAL                   =   2
DBG_UNSUPPORTED                 =   3

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

    def is_gtp_pll_locked(self):
        return self.is_register_bit_set(STATUS, STS_BIT_GTP_PLL_LOCK_DETECT)

    def is_gtp_reset_done(self):
        return self.is_register_bit_set(STATUS, STS_BIT_GTP_RESET_DONE)

    def is_gtp_rx_elec_idle(self):
        return self.is_register_bit_set(STATUS, STS_BIT_RX_ELEC_IDLE)

    def is_pll_locked(self):
        return self.is_register_bit_set(STATUS, STS_BIT_PLL_LOCK_DETECT)

    def get_link_state(self):
        return self.read_register_bit_range(STATUS, STS_BITS_PCIE_LINK_STATE_HIGH, STS_BITS_PCIE_LINK_STATE_LOW)

    def get_link_state_string(self, local_print = False):
        state = self.get_link_state()
        status = ""
        if state == 6:
            status = "Link State (0x%02X): L0" % state
        elif state == 5:
            status = "Link State (0x%02X): L0s" % state
        elif state == 3:
            status = "Link State (0x%02X): L1" % state
        elif state == 7:
            status = "Link state (0x%02X): In Transaciton" % state
        else:
            status = "Link State (0x%02X): Unkown: 0x%02X" % state

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

    def is_turnoff_request(self):
        return self.is_register_bit_set(STATUS, STS_BIT_CFG_TO_TURNOFF)

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

    def get_pcie_clock_count(self):
        return self.read_register(PCIE_CLOCK_CNT)

    def get_debug_pcie_clock_count(self):
        return self.read_register(TEST_CLOCK)

    def set_tx_diff_swing(self, diff_ctrl):
        self.write_register(TX_DIFF_CTRL, diff_ctrl)

    def get_tx_diff_swing(self):
        return self.read_register(TX_DIFF_CTRL)

    def set_rx_equalizer(self, rx_equalizer):
        self.write_register(RX_EQUALIZER_CTRL, rx_equalizer)

    def get_rx_equalizer(self):
        return self.read_register(RX_EQUALIZER_CTRL)

    def get_ltssm_state(self):
        state = self.read_register(LTSSM_STATE)
        if state == 0b00000: return "Detect.Quiet"
        if state == 0b00001: return "Detect.Active"
        if state == 0b00010: return "Polling.Active"
        if state == 0b00011: return "Polling.Config"
        if state == 0b00100: return "Polling Compliance"
        if state == 0b00101: return "Configuration.Linkwidth.Start"
        if state == 0b00110: return "Configuration.Linkwidth.Start"
        if state == 0b00111: return "Configuration.Linkwidth.Accept"
        if state == 0b01000: return "Configuration.Linkwidth.Accept"
        if state == 0b01001: return "Configuration.Lanenum.Wait"
        if state == 0b01010: return "Configuration.Lanenum.Accept"
        if state == 0b01011: return "Configuration.Complete"
        if state == 0b01100: return "Configuration.Idle"
        if state == 0b01101: return "L0"
        if state == 0b01110: return "L1.Entry"
        if state == 0b01111: return "L1.Entry"
        if state == 0b10000: return "L1.Entry"
        if state == 0b10001: return "L1.Idle"
        if state == 0b10010: return "L1.Exit-to-recovery"
        if state == 0b10011: return "Recovery.RcvrLock"
        if state == 0b10100: return "Recovery.RcvrCfg"
        if state == 0b10101: return "Recovery.Idle"
        if state == 0b10110: return "Hot Reset"
        if state == 0b10111: return "Disabled"
        if state == 0b11000: return "Disabled"
        if state == 0b11001: return "Disabled"
        if state == 0b11010: return "Disabled"
        if state == 0b11011: return "Detect.Quiet"
        else:
            return "Unknown State: 0x%02X" % state

    def is_correctable_error(self):
        return self.is_register_bit_set(DBG_DATA, DBG_CORRECTABLE)

    def is_fatal_error(self):
        return self.is_register_bit_set(DBG_DATA, DBG_FATAL)

    def is_non_fatal_error(self):
        return self.is_register_bit_set(DBG_DATA, DBG_NON_FATAL)

    def is_unsupported_error(self):
        return self.is_register_bit_set(DBG_DATA, DBG_UNSUPPORTED)

    def get_cfg_command(self):
        return self.read_register(CONFIG_COMMAND)

    def get_cfg_status(self):
        return self.read_register(CONFIG_STATUS)

    def get_cfg_dcommand(self):
        return self.read_register(CONFIG_DCOMMAND)

    def get_cfg_dstatus(self):
        return self.read_register(CONFIG_DSTATUS)

    def get_cfg_lcommand(self):
        return self.read_register(CONFIG_LCOMMAND)

    def get_cfg_lstatus(self):
        return self.read_register(CONFIG_LSTATUS)

    def get_debug_flags(self):
        return self.read_register(DBG_FLAGS)
