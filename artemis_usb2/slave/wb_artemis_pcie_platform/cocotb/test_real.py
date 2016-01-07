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
        sdio_urn = n.find_device(DRIVER)[0]
        self.driver = DRIVER(n, sdio_urn)
        self.s.set_level("verbose")

        self.s.Info("Using Platform: %s" % plat[0])
        self.s.Info("Instantiated a SDIO Device Device: %s" % sdio_urn)

    def test_device(self):
        self.s.Info("Attempting to set voltage range")
        self.s.Info("Driver Control: 0x%08X" % self.driver.get_control())
        self.s.Info("Enable PCIE")
        #self.driver.enable(False)
        self.driver.enable(True)
        time.sleep(0.5)
        self.s.Info("Is PCIE Reset: %s" % self.driver.is_pcie_reset())
        self.s.Info("Is GTP PLL Locked: %s" % self.driver.is_gtp_pll_locked())
        self.s.Info("Is GTP Reset Done: %s" % self.driver.is_gtp_reset_done())
        self.s.Info("Is GTP RX Electrical Idle: %s" % self.driver.is_gtp_rx_elec_idle())
        self.s.Info("Is PLL Locked: %s" % self.driver.is_pll_locked())
        self.s.Info("Is Linkup: %s" % self.driver.is_linkup())
        self.s.Info("Link State: %s" % self.driver.get_link_state_string())
        self.s.Info("Get Bus Number: 0x%08X" % self.driver.get_bus_num())
        self.s.Info("Get Device Number: 0x%08X" % self.driver.get_dev_num())
        self.s.Info("Get Function Number: 0x%08X" % self.driver.get_func_num())
        self.s.Info("Clock: %d" % self.driver.get_pcie_clock_count())
        self.s.Info("Debug Clock Data: %d" % self.driver.get_debug_pcie_clock_count())


if __name__ == "__main__":
    unittest.main()

