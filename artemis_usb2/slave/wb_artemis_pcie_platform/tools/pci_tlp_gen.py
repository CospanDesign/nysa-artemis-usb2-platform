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

from array import array as Array

#sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

from tlp_common import print_raw_packet
from tlp_manager import TLPManager

NAME = os.path.basename(os.path.realpath(__file__))

DESCRIPTION = "\n" \
              "\n" \
              "usage: %s [options]\n" % NAME

EPILOG = "\n" \
         "\n" \
         "Examples:\n" \
         "\tSomething\n" \
         "\n"


'''
    Not Supported Yet:
        Extended Tag
        Phantom Functions
        ST Function (Associated with TH bit)
'''



def main(argv):
    #Parse out the commandline arguments
    parser = argparse.ArgumentParser(
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description=DESCRIPTION,
        epilog=EPILOG
    )

    parser.add_argument("-n", "--name",
                        nargs=1,
                        default=["mwr"])

    parser.add_argument("-d", "--debug",
                        action="store_true",
                        help="Enable Debug Messages")

    args = parser.parse_args()
    print "Running Script: %s" % NAME
    name = args.name[0]

    tm = TLPManager()

    if args.debug:
        tm.set_value("type", name)
        print "Pretty Print"
        tm.pretty_print()

        print "Raw Packet:"
        print print_raw_packet(tm.generate_raw(), tab = 1)
        tm.parse_raw(tm.generate_raw())
        print print_raw_packet(tm.generate_raw(), tab = 1)
        tm.pretty_print()

        


if __name__ == "__main__":
    main(sys.argv)


