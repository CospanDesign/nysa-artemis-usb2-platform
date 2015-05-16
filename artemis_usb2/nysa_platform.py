#Distributed under the MIT licesnse.
#Copyright (c) 2014 Dave McCoy (dave.mccoy@cospandesign.com)

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

"""
Artemis Interface
"""
__author__ = 'dave.mccoy@cospandesign.com (Dave McCoy)'

import sys
import os
import subprocess

from nysa.host.nysa_platform import Platform
import usb.core
import usb.util
from ftdi import Ftdi

sys.path.append(os.path.join(os.path.dirname(__file__),
                             os.pardir,
                             os.pardir))

import nysa
from nysa.ibuilder.lib.xilinx_utils import find_xilinx_path
from artemis_usb2 import Artemis

class ArtemisUSB2Platform(Platform):

    def __init__(self, status = None):
        super (ArtemisUSB2Platform, self).__init__(status)
        self.vendor = 0x0403
        self.product = 0x8531

    def get_type(self):
        return "artemis_usb2"

    def scan(self):
        self.status.Verbose("Scanning")
        devices = usb.core.find(find_all = True)
        for device in devices:
            if device.idVendor == self.vendor and device.idProduct == self.product:
                self.add_device_dict(device.serial_number, Artemis(idVendor = self.vendor,
                                                      idProduct = self.product,
                                                      sernum = device.serial_number,
                                                      status = self.status))
        return self.dev_dict

    def test_build_tools(self):
        if find_xilinx_path() is None:
            return False
        return True

    def setup_platform(self):
        if SYSTEM_NAME == "Linux":
            print "linux distribution: %s" % SYSTEM_DIST[0]
            source_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "board", "66-artemis-usb2.rules"))
            if SYSTEM_DIST[0] == "Ubuntu":
                print "Found Ubuntu platform, copying over rules, make sure to restart udev rules"
                dest_path = "/etc/udev/rules.d/66-artemis-usb2.rules"
                cmd = ["sudo", "cp", source_path, dest_path]
                v = subprocess.call(cmd)

        if SYSTEM_NAME == "Windows":
            print "Windows box!"
        return

