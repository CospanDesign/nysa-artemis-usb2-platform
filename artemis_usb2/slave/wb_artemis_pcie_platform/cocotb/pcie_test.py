#! /usr/bin/env python

# Copyright (c) 2016 Dave McCoy (dave.mccoy@cospandesign.com)
#
# NAME is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# NAME is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NAME; If not, see <http://www.gnu.org/licenses/>.


import sys
import os
import argparse
import logging

#sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))
from pcie_driver import DEFAULT_DEVNAME
from pcie_driver import PCIE_NAME

from pcie_driver import PCIE
from pcie_driver import PCIE_REGISTERS as REG


NAME = os.path.basename(os.path.realpath(__file__))

DESCRIPTION = "\n" \
              "\n" \
              "usage: %s [options]\n" % NAME

EPILOG = "\n" \
         "\n" \
         "Examples:\n" \
         "\tSomething\n" \
         "\n"

reg_test_dict = {
#    REG.BUFFER_READY     :  0x02
    REG.WRITE_BUF_A_ADDR :  0xAAAAAAAA
#    REG.WRITE_BUF_B_ADDR :  0xBBBBBBBB
#    REG.READ_BUF_A_ADDR  :  0xCCCCCCCC
#    REG.READ_BUF_B_ADDR  :  0x01234567
#    REG.BUFFER_SIZE      :  0xDEADBEEF
#    REG.PING_VALUE       :  0xDEADCA75
}

def test_register_write(pcie):
    #for r in reg_test_dict:
    pcie.write_register(REG.WRITE_BUF_A_ADDR, 0xDEADCA75)
    print "Done!"

def main(argv):
    #Parse out the commandline arguments
    logger = logging.getLogger(PCIE_NAME)
    logger.setLevel(logging.INFO)
    formatter = logging.Formatter('%(filename)s:%(module)s:%(funcName)s: %(message)s')

    #Create a Console Handler
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=DESCRIPTION,
        epilog=EPILOG
    )

    parser.add_argument("--device",
                        nargs=1,
                        default=[DEFAULT_DEVNAME],
                        help = "Change the device to open, default: %s" % DEFAULT_DEVNAME)
    parser.add_argument("-d", "--debug",
                        action="store_true",
                        help="Enable Debug Messages")

    args = parser.parse_args()
    print "Running Script: %s" % NAME

    if args.debug:
        print "Device to open: %s" % str(args.device[0])
        logger.setLevel(logging.DEBUG)

    if args.debug: print "Parse arguments"
    device_name = args.device[0]



    #Generate the instance
    pcie = PCIE(device_name)

    #Execute the tests
    test_register_write(pcie)
    del(pcie)

if __name__ == "__main__":
    main(sys.argv)


