#Distributed under the MIT licesnse.
#Copyright (c) 2015 Dave McCoy (dave.mccoy@cospandesign.com)

#Permission is hereby granted, free of charge, to any person obtaining a copy of
#this software and associated documentation files (the "Software"), to deal in
#the Software without restriction, including without limitation the rights to
#use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
#of the Software, and to permit persons to whom the Software is furnished to do
#so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

""" DMA

Facilitates communication with the DMA controller

"""

__author__ = 'dave.mccoy@cospandesign.com (Dave McCoy)'

import sys
import os
import time

from array import array as Array


from nysa.host.driver import driver


#Artemis USB2 Identifier
ARTEMIS_USB2_ID        = 0x03

#Register Constants
CONTROL                = 0x00
STATUS                 = 0x01
SATA_CLK_COUNT         = 0x02
SATA_FST_CLK_COUNT     = 0x03

PCIE_RESET             = 2
SATA_RESET             = 3
GTP_RX_PRE_AMP_LOW     = 4
GTP_RX_PRE_AMP_HIGH    = 5
GTP_TX_DIFF_SWING_LOW  = 8
GTP_TX_DIFF_SWING_HIGH = 11
PCIE_RX_POLARITY       = 12


SATA_PLL_DETECT_K      = 0
PCIE_PLL_DETECT_K      = 1
SATA_RESET_DONE        = 2
PCIE_RESET_DONE        = 3
SATA_DCM_PLL_LOCKED    = 4
PCIE_DCM_PLL_LOCKED    = 5
SATA_RX_IDLE           = 6
PCIE_RX_IDLE           = 7
SATA_TX_IDLE           = 8
PCIE_TX_IDLE           = 9
SATA_LOSS_OF_SYNC      = 10
PCIE_LOSS_OF_SYNC      = 11
SATA_BYTE_IS_ALIGNED   = 12
PCIE_BYTE_IS_ALIGNED   = 13


class ArtemisUSB2DriverError(Exception):
    pass


class ArtemisUSB2Driver(driver.Driver):
    """
    Artemis Driver
    """
    @staticmethod
    def get_abi_class():
        return 0

    @staticmethod
    def get_abi_major():
        return driver.get_device_id_from_name("platform")

    @staticmethod
    def get_abi_minor():
        return ARTEMIS_USB2_ID

    def __init__(self, nysa, urn, debug = False):
        super (ArtemisUSB2Driver, self).__init__(nysa, urn, debug)

    def __del__(self):
        pass

    def enable_pcie_reset(self, enable):
        """
        Reset the PCIE GTP State Machine

        Args:
            enable: Reset
            enable: Release Reset

        Returns:
            Nothing

        Raises:
            Nothing
        """

        self.enable_register_bit(CONTROL, PCIE_RESET, enable)

    def enable_sata_reset(self, enable):
        """
        Reset the SATA GTP State Machine

        Args:
            enable: Reset
            enable: Release Reset

        Returns:
            Nothing

        Raises:
            Nothing
        """

        self.enable_register_bit(CONTROL, SATA_RESET, enable)

    def set_gtp_rx_preamp(self, value):
        """
        Set the value of the Receiver Preamplifier (0 - 7)

        Args:
            value (Integer): 0 - 7 (Higher has more gain)

        Returns:
            Nothing

        Raises:
            Nothing
        """

        reg = self.read_register(CONTROL)
        bitmask = (((1 << (GTP_RX_PRE_AMP_HIGH + 1))) - (1 << GTP_RX_PRE_AMP_LOW))
        reg &= ~(bitmask)
        reg |= value << GTP_RX_PRE_AMP_LOW
        self.write_register(CONTROL, reg)

    def set_gtp_tx_diff_swing(self, value):
        """
        Sets the value of the transmitter differential swing

        Args:
            value (Integer): 0 - 3 (Higher has larger swing)

        Returns:
            Nothing

        Raises:
            Nothing
        """

        reg = self.read_register(CONTROL)
        bitmask = (((1 << (GTP_TX_DIFF_SWING_HIGH + 1))) - (1 << GTP_TX_DIFF_SWING_LOW))
        reg &= ~(bitmask)
        reg |= value << GTP_TX_DIFF_SWING_LOW
        self.write_register(CONTROL, reg)

    def set_pcie_rx_polarity(self, positive):
        """
        Sets the polarity of the PCIE Receiver phy signals
        Note: A reset of the GTP stack is probably required after this

        Args:
            positive: If set true this will set the polarity positive

        Returns:
            Nothing

        Raises:
            Nothing
        """
        self.enable_register_bit(CONTROL, PCIE_RX_POLARITY, not positive)

    def is_pcie_reset(self):
        """
        Return true if  the GTP State machine for the PCIE is in reset state

        Args:
            Nothing

        Returns (Boolean):
            True: PCIE state machine is in a reset state
            False: PCIE state machine is not in a reset state

        Raises:
            Nothing
        """

        return self.is_register_bit_set(CONTROL, PCIE_RESET)

    def is_sata_reset(self):
        """
        Return true if  the GTP State machine for the SATA is in reset state

        Args:
            Nothing

        Returns (Boolean):
            True: SATA state machine is in a reset state
            False: SATA state machine is not in a reset state

        Raises:
            Nothing
        """
        return self.is_register_bit_set(CONTROL, SATA_RESET)

    def get_gtp_rx_preamp(self):
        """
        Gets the current pre amplifier settings for the receiver

        Args:
            Nothing

        Returns (Integer):
            3-bit value between 0 to 7

        Raises:
            Nothing
        """
        value = self.read_register(CONTROL)
        bitmask = (((1 << (GTP_RX_PRE_AMP_HIGH + 1))) - (1 << GTP_RX_PRE_AMP_LOW))
        value = value & bitmask
        value = value >> GTP_RX_PRE_AMP_LOW
        return value

    def get_gtp_tx_diff_swing(self):
        """
        Gets the current transmitter differential swing settings

        Args:
            Nothing

        Returns (Integer):
            2-bit value between 0 to 3

        Raises:
            Nothing
        """
        value = self.read_register(CONTROL)
        bitmask = ((1 << (GTP_TX_DIFF_SWING_HIGH + 1)) - (1 << GTP_TX_DIFF_SWING_LOW))
        value = value & bitmask
        value = value >> GTP_TX_DIFF_SWING_LOW
        return value

    def is_pcie_rx_polarity_positive(self):
        """
        Returns True if the polarity of the PCIE Receiver is positive

        Args:
            Nothing

        Returns (Boolean):
            True: Polarity is positive
            False: Polarity is negative

        Raises:
            Nothing
        """
        return not self.is_register_bit_set(CONTROL, PCIE_RX_POLARITY)

    def is_sata_pll_locked(self):
        """
        Returns True if the GTP SATA PLL is locked

        Args:
            Nothing

        Returns (Boolean):
            True: PLL is Locked
            False: PLL is not Locked

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, SATA_PLL_DETECT_K)

    def is_pcie_pll_locked(self):
        """
        Returns True if the GTP PCIE PLL is locked

        Args:
            Nothing

        Returns (Boolean):
            True: PLL is Locked
            False: PLL is not Locked

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, PCIE_PLL_DETECT_K)

    def is_sata_reset_done(self):
        """
        Returns True if the SATA GTP state machine has finished it's reset
        sequency

        Args:
            Nothing

        Returns (Boolean):
            True: SATA GTP is ready
            False: SATA GTP is not ready

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, SATA_RESET_DONE)

    def is_pcie_reset_done(self):
        """
        Returns True if the PCIE GTP state machine has finished it's reset
        sequency

        Args:
            Nothing

        Returns (Boolean):
            True: PCIE GTP is ready
            False: PCIE GTP is not ready

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, PCIE_RESET_DONE)

    def is_sata_dcm_pll_locked(self):
        """
        Returns True if the DCM that synthesizes the two user clocks for SATA
        (300MHz and 75MHz) is locked

        Args:
            Nothing

        Returns (Boolean):
            True: DCM locked
            False: DCM is not locked

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, SATA_DCM_PLL_LOCKED)

    def is_pcie_dcm_pll_locked(self):
        """
        Returns True if the DCM that synthesizes the two user clocks for PCIE
        (250MHz and 62.5MHz) is locked

        Args:
            Nothing

        Returns (Boolean):
            True: DCM locked
            False: DCM is not locked

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, PCIE_DCM_PLL_LOCKED)

    def is_sata_rx_idle(self):
        """
        Returns True if SATA receiver is idle

        Args:
            Nothing

        Returns (Boolean):
            True: SATA Receiver is receiving an IDLE signal (no activity)
            False: SATA Receiver is currently active
            
        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, SATA_RX_IDLE)

    def is_pcie_rx_idle(self):
        """
        Returns True if PCIE receiver is idle

        Args:
            Nothing

        Returns (Boolean):
            True: PCIE Receiver is receiving an IDLE signal (no activity)
            False: PCIE Receiver is currently active
            
        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, PCIE_RX_IDLE)

    def is_sata_tx_idle(self):
        """
        Returns True if SATA transmitter is idle

        Args:
            Nothing

        Returns (Boolean):
            True: SATA Receiver is receiving an IDLE signal (no activity)
            False: SATA Receiver is currently active
            
        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, SATA_TX_IDLE)

    def is_pcie_tx_idle(self):
        """
        Returns True if PCIE transmitter is idle

        Args:
            Nothing

        Returns (Boolean):
            True: PCIE Receiver is receiving an IDLE signal (no activity)
            False: PCIE Receiver is currently active
            
        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, PCIE_TX_IDLE)

    def is_sata_lost_sync(self):
        """
        Returns True if SATA Receiver has lost synchronization with the hard
        drive

        Args:
            Nothing

        Returns (Boolean):
            True: SATA Receiver has lost sync with the hard drive
            False: SATA Receiver has not lost sync with the hard drive

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, SATA_LOSS_OF_SYNC)

    def is_pcie_lost_sync(self):
        """
        Returns True if PCIE Receiver has lost synchronization with the host

        Args:
            Nothing

        Returns (Boolean):
            True: PCIE Receiver has lost sync with the host
            False: PCIE Receiver has not lost sync with the host

        Raises:
            Nothing
        """
        return self.is_register_bit_set(STATUS, PCIE_LOSS_OF_SYNC)

    def get_ref_clock_count(self):
        return self.read_register(SATA_CLK_COUNT);

    def get_ref_fst_clock_count(self):
        return self.read_register(SATA_FST_CLK_COUNT);

    def is_sata_byte_aligned(self):
        return self.is_register_bit_set(STATUS, SATA_BYTE_IS_ALIGNED)

    def is_pcie_byte_aligned(self):
        return self.is_register_bit_set(STATUS, PCIE_BYTE_IS_ALIGNED)


