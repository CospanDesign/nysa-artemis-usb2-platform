#!/usr/bin/env python

import unittest
import json
import sys
import os
import time
from array import array as Array

sys.path.append(os.path.join(os.path.dirname(__file__),
                             os.pardir,
                             os.pardir))

from nysa.common.status import Status
from nysa.host.driver.utils import *

from nysa.host.platform_scanner import PlatformScanner

from dut_driver import ArtemisPCIEDriver
DRIVER = ArtemisPCIEDriver


class Test (unittest.TestCase):

    def setUp(self):
        self.s = Status()
        plat = ["", None, None]
        pscanner = PlatformScanner()
        platform_dict = pscanner.get_platforms()
        platform_names = platform_dict.keys()

        if "sim" in platform_names:
            #If sim is in the platforms, move it to the end
            platform_names.remove("sim")
            platform_names.append("sim")
        urn = None
        for platform_name in platform_names:
            if plat[1] is not None:
                break

            self.s.Debug("Platform: %s" % str(platform_name))

            platform_instance = platform_dict[platform_name](self.s)
            #self.s.Verbose("Platform Instance: %s" % str(platform_instance))

            instances_dict = platform_instance.scan()

            for name in instances_dict:

                #s.Verbose("Found Platform Item: %s" % str(platform_item))
                n = instances_dict[name]
                plat = ["", None, None]

                if n is not None:
                    self.s.Important("Found a nysa instance: %s" % name)
                    n.read_sdb()
                    #import pdb; pdb.set_trace()
                    if n.is_device_in_platform(DRIVER):
                        plat = [platform_name, name, n]
                        break
                    continue

                #self.s.Verbose("\t%s" % psi)

        if plat[1] is None:
            self.driver = None
            return
        n = plat[2]
        self.n = n
        pcie_urn = n.find_device(DRIVER)[0]
        self.driver = DRIVER(n, pcie_urn)
        self.s.set_level("verbose")

        self.s.Info("Using Platform: %s" % plat[0])
        self.s.Info("Instantiated a PCIE Device Device: %s" % pcie_urn)

    def test_device(self):

        TX_DIFF_CTRL = 0x07
        TX_PRE_EMPH = 0x00
        RX_EQUALIZER = 0x3


        self.s.Info("Attempting to set voltage range")
        self.s.Info("Enable PCIE")

        '''
        self.driver.enable(False)
        self.driver.enable_pcie_read_block(True)
        self.driver.enable_external_reset(True)



        #self.driver.enable_manual_reset(True)
        #self.driver.enable_manual_reset(False)

        self.s.Info("Is external reset enabled: %s" % str(self.driver.is_external_reset_enabled()))
        self.s.Info("Driver Control: 0x%08X" % self.driver.get_control())
        self.driver.set_tx_diff_swing(TX_DIFF_CTRL)
        #self.driver.set_tx_pre_emph(TX_PRE_EMPH)
        self.driver.set_rx_equalizer(RX_EQUALIZER)
        self.s.Important("Tx Diff Swing: %d" % self.driver.get_tx_diff_swing())
        self.s.Important("RX Equalizer: %d" % self.driver.get_rx_equalizer())
        time.sleep(0.5)
        self.driver.enable(True)
        time.sleep(0.5)
        self.s.Info("Driver Control: 0x%08X" % self.driver.get_control())
        '''

        self.s.Verbose("Is GTP PLL Locked: %s" % self.driver.is_gtp_pll_locked())
        self.s.Verbose("Is GTP Reset Done: %s" % self.driver.is_gtp_reset_done())
        self.s.Verbose("Is GTP RX Electrical Idle: %s" % self.driver.is_gtp_rx_elec_idle())
        self.s.Verbose("Is PLL Locked: %s" % self.driver.is_pll_locked())
        self.s.Verbose("Is Host Holding Reset: %s" % self.driver.is_host_set_reset())

        if self.driver.is_pcie_reset():
            self.s.Error("PCIE_A1 Core is in reset!")

        if self.driver.is_linkup():
            self.s.Important("PCIE Linked up!")
        else:
            self.s.Error("PCIE Core is not linked up!")

        self.s.Important("LTSSM State: %s" % self.driver.get_ltssm_state())

        if self.driver.is_correctable_error():
            self.s.Error("Correctable Error Detected")

        if self.driver.is_fatal_error():
            self.s.Error("Fatal Error Detected")

        if self.driver.is_non_fatal_error():
            self.s.Error("Non Fatal Error Detected")

        if self.driver.is_unsupported_error():
            self.s.Error("Unsupported Error Detected")


        self.s.Info("Link State: %s" % self.driver.get_link_state_string())
        self.s.Info("Get Bus Number: 0x%08X" % self.driver.get_bus_num())
        self.s.Info("Get Device Number: 0x%08X" % self.driver.get_dev_num())
        self.s.Info("Get Function Number: 0x%08X" % self.driver.get_func_num())
        self.s.Info("Clock: %d" % self.driver.get_pcie_clock_count())
        self.s.Info("Debug Clock Data: %d" % self.driver.get_debug_pcie_clock_count())

        self.s.Info("Hot Reset: %s" % self.driver.is_hot_reset())
        self.s.Info("Config Turnoff Request: %s" % self.driver.is_turnoff_request())

        self.s.Info("Config Command:    0x%04X" % self.driver.get_cfg_command())
        self.s.Info("Config Status:     0x%04X" % self.driver.get_cfg_status())
        self.s.Info("Config DCommand:   0x%04X" % self.driver.get_cfg_dcommand())
        self.s.Info("Config DStatus:    0x%04X" % self.driver.get_cfg_dstatus())
        self.s.Info("Config LCommand:   0x%04X" % self.driver.get_cfg_lcommand())
        self.s.Info("Config LStatus:    0x%04X" % self.driver.get_cfg_lstatus())

        #self.s.Info("Debug Flags: 0x%08X" % self.driver.get_debug_flags())
        self.driver.read_debug_flags()

        print "Buffer:"
        print "%s" % list_to_hex_string(self.driver.read_local_buffer())

if __name__ == "__main__":
    unittest.main()

