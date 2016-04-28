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
TX_PRE_EMPH                     =   9
DBG_DATA                        =   10
CONFIG_COMMAND                  =   11
CONFIG_STATUS                   =   12
CONFIG_DCOMMAND                 =   13
CONFIG_DSTATUS                  =   14
CONFIG_LCOMMAND                 =   15
CONFIG_LSTATUS                  =   16
DBG_FLAGS                       =   17
BAR_SELECT                      =   18
BAR_ADDR0                       =   19
BAR_ADDR1                       =   20
BAR_ADDR2                       =   21
BAR_ADDR3                       =   22
BAR_ADDR4                       =   23
BAR_ADDR5                       =   24
IRQ_CHANNEL_SELECT              =   25
CFG_READ_EXEC                   =   26
CFG_SM_STATE                    =   27
CTR_SM_STATE                    =   28
INGRESS_COUNT                   =   29
INGRESS_STATE                   =   30
INGRESS_RI_COUNT                =   31
INGRESS_CI_COUNT                =   32
INGRESS_ADDR                    =   33


BAR_ADDR_BASE                   =   19

CTRL_BIT_ENABLE                 =   0
CTRL_BIT_SEND_CONTROL_BLOCK     =   1
CTRL_BIT_CANCEL_SEND_BLOCK      =   2
CTRL_BIT_ENABLE_LOCAL_READ      =   3
CTRL_BIT_ENABLE_EXT_RESET       =   4
CTRL_BIT_MANUAL_USER_RESET      =   5
CTRL_BIT_RESET_DBG_REGS         =   6
CTRL_BIT_READ_BAR_ADDR_STB      =   7
CTRL_BIT_SEND_IRQ               =   8

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
STS_BIT_PCIE_EXT_RESET          =   30
STS_BIT_AXI_RECEIVE_READY       =   31



DBG_DTCT_CRCT                   =   0
DBG_DTCT_FATL                   =   1
DBG_DTCT_NFTL                   =   2
DBG_DTCT_UNSP                   =   3
DBG_DLLP_STS                    =   4
DBG_BD_TLP_LCRC                 =   5
DBG_BD_TLP_SQNM                 =   6
DBG_BD_TLP_STS                  =   7
DBG_DL_PTCL_STS                 =   8
DBG_FC_PTCL_STS                 =   9
DBG_MLFM_LEN                    =   10
DBG_MLFM_MPS                    =   11
DBG_MLFM_TCVC                   =   12
DBG_MLFM_TLP_STS                =   13
DBG_MLFM_TLP_UNREC              =   14
DBG_PLP_STS                     =   15
DBG_RCVR_OVFL_STS               =   16
DBG_RCVR_RLVR_STS               =   17
DBG_RCVR_TMT_STS                =   18
DBG_UR_NO_BAR                   =   19
DBG_UR_POIS                     =   20
DBG_UR_STS                      =   21
DBG_UR_UNSUP_MSG                =   22



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
        self.set_register_bit(CONTROL, CTRL_BIT_CANCEL_SEND_BLOCK)

    def get_status(self):
        return self.read_register(STATUS)

    def is_pcie_reset(self):
        return self.is_register_bit_set(STATUS, STS_BIT_PCIE_RESET)

    def is_axi_receive_ready(self):
        return self.is_register_bit_set(STATUS, STS_BIT_AXI_RECEIVE_READY)

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

    def is_host_set_reset(self):
        return self.is_register_bit_set(STATUS, STS_BIT_PCIE_EXT_RESET)

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

    def get_pcie_clock_count(self):
        return self.read_register(PCIE_CLOCK_CNT)

    def get_debug_pcie_clock_count(self):
        return self.read_register(TEST_CLOCK)

    def set_tx_diff_swing(self, diff_ctrl):
        self.write_register(TX_DIFF_CTRL, diff_ctrl)

    def get_tx_diff_swing(self):
        return self.read_register(TX_DIFF_CTRL)

    def set_tx_pre_emph(self, value):
        self.write_register(TX_PRE_EMPH, value)

    def get_tx_pre_emph(self):
        return self.read_register(TX_PRE_EMPH)

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

    def read_debug_flags(self):
        flags = self.get_debug_flags()
        print "PCIE Debug Flags:"
        #print "\tGeneral Errors:"
        if (flags & (1 << DBG_DTCT_CRCT) > 0):
            print "\tDetect Correctable Error"
        if (flags & (1 << DBG_DTCT_FATL) > 0):
            print "\tDetect Fatal Error"
        if (flags & (1 << DBG_DTCT_NFTL) > 0):
            print "\tDetect Non Fatal Error"
        if (flags & (1 << DBG_DTCT_UNSP) > 0):
            print "\tDetect Unsupported Error"
        print ""
        #print "\tSpecific Errors:"
        if (flags & (1 << DBG_DLLP_STS)) > 0:
            print "\tBad DLLP CRC Error"
        if (flags & (1 << DBG_BD_TLP_LCRC)) > 0:
            print "\tLCP with an LCRC Error detected"
        if (flags & (1 << DBG_BD_TLP_SQNM)) > 0:
            print "\tTLP with an invalid sequence number"
        if (flags & (1 << DBG_BD_TLP_STS)) > 0:
            print "\tTLP with an error detected"
        if (flags & (1 << DBG_DL_PTCL_STS)) > 0:
            print "\tOut of Range ACK or NACK is received"
        if (flags & (1 << DBG_FC_PTCL_STS)) > 0:
            print "\tProtocol error with the received flow control update"
        if (flags & (1 << DBG_MLFM_LEN)) > 0:
            print "\tTLP Length did not match what was in the TLP header"
        if (flags & (1 << DBG_MLFM_MPS)) > 0:
            print "\tTLP Length had a length that did not match the negotiated MPS"
        if (flags & (1 << DBG_MLFM_TCVC)) > 0:
            print "\tInvalid TC or VC value"
        if (flags & (1 << DBG_MLFM_TLP_STS)) > 0:
            print "\tMalformed TLP is received"
        if (flags & (1 << DBG_MLFM_TLP_UNREC)) > 0:
            print "\tTLP had invalid/unrecognized field"
        if (flags & (1 << DBG_PLP_STS)) > 0:
            print "\tTLP was received with the EP (poisoned status bit set)"
        if (flags & (1 << DBG_RCVR_OVFL_STS)) > 0:
            print "\tTLP violates the advertise credits"
        if (flags & (1 << DBG_RCVR_RLVR_STS)) > 0:
            print "\tRollover counter expires"
        if (flags & (1 << DBG_RCVR_TMT_STS)) > 0:
            print "\tReplay time-out conter expires"
        if (flags & (1 << DBG_UR_NO_BAR)) > 0:
            print "\tReceived read/write did not match a configured BAR"
        if (flags & (1 << DBG_UR_POIS)) > 0:
            print "\tCFGWR TLP with the error/poisoned bit (EP) =  was received"
        if (flags & (1 << DBG_UR_STS)) > 0:
            print "\tUnsupported request is recieved"
        if (flags & (1 << DBG_UR_UNSUP_MSG)) > 0:
            print "\tMSG or MSGD TLP with unsupported type was received"

    def get_debug_flags(self):
        return self.read_register(DBG_FLAGS)

    def reset_debug_flags(self):
        self.set_register_bit(CONTROL, CTRL_BIT_RESET_DBG_REGS);

    def enable_external_reset(self, enable):
        self.enable_register_bit(CONTROL, CTRL_BIT_ENABLE_EXT_RESET, enable)

    def is_external_reset_enabled(self):
        return self.is_register_bit_set(CONTROL, CTRL_BIT_ENABLE_EXT_RESET)

    def enable_manual_reset(self, enable):
        self.enable_register_bit(CONTROL, CTRL_BIT_MANUAL_USER_RESET, enable)

    def is_manual_reset_set(self):
        return self.enable_register_bit(CONTROL, CTRL_BIT_MANUAL_USER_RESET)

    def get_bar_select(self):
        return self.read_register(BAR_SELECT)

    def get_num_block_reads(self):
        return self.read_register(NUM_BLOCK_READ)

    def get_bar_address(self, bar_index):
        if bar_index > 5:
            return 0
        if bar_index < 0:
            return 0
        return self.read_register(BAR_ADDR_BASE + bar_index)

    def get_config_data(self):
        self.set_register_bit(CONTROL, CTRL_BIT_READ_BAR_ADDR_STB)

    def send_irq(self):
        self.set_register_bit(CONTROL, CTRL_BIT_SEND_IRQ)

    def set_interrupt_channel(self, channel):
        self.write_register(IRQ_CHANNEL_SELECT, channel)

    def get_interrupt_channel(self):
        return self.read_register(IRQ_CHANNEL_SELECT)

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

    def get_ingress_addr(self):
        return self.read_register(INGRESS_ADDR)




