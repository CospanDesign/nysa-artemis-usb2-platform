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

from tlp_transfer import TLPTransfer
#sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

TLP_TYPE = "mwr"


class TLPMemoryWrite(TLPTransfer):

    @staticmethod
    def get_fields():
        return TLPTransfer.get_fields()

    @staticmethod
    def get_type():
        return TLP_TYPE

    @staticmethod
    def get_description(key):
        return TLPTransfer.get_description(key)

    def __init__(self):
        super (TLPMemoryWrite, self).__init__()

    def initialize(self):
        super (TLPMemoryWrite, self).initialize()
        self.set_value("type", TLP_TYPE)
        self.set_value("has_data", True)
        self.set_value("dword_count", 1)

    def generate_raw(self):
        raw = super (TLPMemoryWrite, self).generate_raw()
        #Add Next Line
        dword_count = self.get_value("dword_count")
        requester_id = self.get_value("requester_id")
        tag = self.get_value("tag")
        first_byte_enable = self.get_value("first_be")
        last_byte_enable = self.get_value("last_be")
        address = self.get_value("address")

        if not self.get_value("has_data"):
            dword_count = 0

        if dword_count == 0:
            first_byte_enable = 0x00
            last_byte_enable = 0x00
        if dword_count == 1:
            last_byte_enable = 0x00


        raw.append((requester_id >> 8) & 0xFF)
        raw.append(requester_id & 0xFF)
        raw.append(tag & 0xFF)
        raw.append((last_byte_enable << 4) | (first_byte_enable & 0xFF))

        if self.get_value("64bit"):
            raw.append((address >> 56) & 0xFF)
            raw.append((address >> 48) & 0xFF)
            raw.append((address >> 40) & 0xFF)
            raw.append((address >> 32) & 0xFF)

        raw.append((address >> 24) & 0xFF)
        raw.append((address >> 16) & 0xFF)
        raw.append((address >>  8) & 0xFF)
        raw.append((address >>  0) & 0xFC)
        raw.extend(self.data)
        return raw

    def set_value(self, key, value):
        super (TLPMemoryWrite, self).set_value(key, value)

    def get_value(self, key):
        return super (TLPMemoryWrite, self).get_value(key)

    def pretty_print(self):
        return super(TLPMemoryWrite, self).pretty_print()



