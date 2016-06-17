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

def create_inc_buf(count):
    buf = Array('B')
    for i in range(count):
        buf.append(i % 256)
    return buf

def create_empty_buf(count):
    buf = Array('B')
    for i in range(count):
        buf.append(0x00)
    return buf


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

        self.s.Info("Ingress State:          0x%04X" % self.driver.get_ingress_state())
        self.s.Info("Ingress Count:          %d" % self.driver.get_ingress_count())
        print ""
        self.s.Info("Ingress RI Count:       %d" % self.driver.get_ingress_ri_count())
        self.s.Info("Ingress CI Count:       %d" % self.driver.get_ingress_ci_count())
        self.s.Info("Ingress CMPLT Count:    %d" % self.driver.get_ingress_cmplt_count())
        self.s.Info("Ingress Address:        0x%08X" % self.driver.get_ingress_addr())
        print ""
        self.s.Info("Config Read Count:      %d" % self.driver.get_config_state_read_count())
        self.s.Info("Config State:           0x%04X" % self.driver.get_config_state())
        print ""
        self.s.Info("PCIE Controller State:  0x%04X" % self.driver.get_control_state())
        print ""
        self.s.Info("HI Input State:         0x%04X" % self.driver.get_ih_state())
        self.s.Info("HI Output State:        0x%04X" % self.driver.get_oh_state())


        count = self.driver.get_local_buffer_size()
        data = Array('B')
        for i in range(count):
            v = i * 4
            data.append(0xFF)
            data.append(0xFF)
            data.append(0xFF)
            data.append(0xFF)
 
        self.driver.write_local_buffer(data)
        data = self.driver.read_local_buffer()

        print "Buffer:"
        #for i in range(0, len(data), 4):
        for i in range(0, 4 * 8, 4):
            print "[%04X] 0x%08X" % (i, array_to_dword(data[i:i + 4]))



if __name__ == "__main__":
    unittest.main()

