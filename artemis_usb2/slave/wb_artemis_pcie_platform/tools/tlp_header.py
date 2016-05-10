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
from tlp_type import TLPType
from tlp_flags import TLPFlags
from tlp_common import print_raw_packet

DWORD_COUNT = "dword_count"
HAS_DATA = "has_data"

DESCRIPTION_DICT = {
    DWORD_COUNT:    "Number of 32-bit values to transfer",
    HAS_DATA:       "This packet can have data"
}

FIELDS = [DWORD_COUNT, HAS_DATA]

class TLPHeader(object):

    @staticmethod
    def get_fields():
        fields = TLPType.get_fields()
        fields.extend(TLPFlags.get_fields())
        fields.extend(FIELDS)
        return fields

    @staticmethod
    def get_type():
        raise AssertionError("This should be set by subclass")

    @staticmethod
    def get_description(key):
        if key in DESCRIPTION_DICT.keys():
            return DESCRIPTION_DICT[key]
        elif key in TLPTypes.get_fields():
            return TLPTypes.get_description(key)
        elif key in TLPFlags.get_fields():
            return TLPFlags.get_description(key)
        raise AssertionError("%s could not be found, valid values are %s" % (key, TLPHeader.get_fields()))

    def __init__(self):
        self.tlp_type = TLPType()
        self.tlp_flags = TLPFlags()
        self.initialize()

    def initialize(self):
        self.set_value(DWORD_COUNT, 0x01)
        self.tlp_type.initialize()
        self.tlp_flags.initialize()

    def generate_raw(self):
        #generate the type byte
        type_byte = self.tlp_type.generate_raw()
        #generate the flags
        flag_data = self.tlp_flags.generate_raw()
        #Generate the dword count
        dword_count = self.get_value(DWORD_COUNT)
        raw = Array('B')
        raw.append(type_byte)
        raw.append((flag_data >> 6) & 0xFF)
        val = (((flag_data << 2) & 0xFC) | (dword_count >> 8) & 0x3)
        raw.append(val & 0xFF)
        raw.append(dword_count & 0xFF)
        return raw

    def parse_raw(self, raw):
        flag_data = (raw[1] << 8) | raw[2]
        flag_data = (flag_data >> 2) & 0x3FFF
        data_length = (raw[2] << 8) | (raw[3])
        data_length &= 0x3FF
        self.tlp_flags.parse_flags(flag_data)
        self.set_value(DWORD_COUNT, data_length)

    def set_value(self, key, value):
        if key in TLPType.get_fields():
            self.tlp_type.set_value(key, value)
        elif key in TLPFlags.get_fields():
            self.tlp_flags.set_value(key, value)
        elif key in FIELDS:
            if key == DWORD_COUNT:
                self.dword_count = value
            if key == HAS_DATA:
                self.has_data = value

        else:
            raise AssertionError("%s is not a valid field: %s" % (key, TLPHeader.get_fields()))

    def get_value(self, key):
        if key in TLPType.get_fields():
            return self.tlp_type.get_value(key)
        elif key in TLPFlags.get_fields():
            return self.tlp_flags.get_value(key)
        elif key in FIELDS:
            if key == DWORD_COUNT:
                return self.dword_count
            if key == HAS_DATA:
                return self.has_data

        else:
            raise AssertionError("%s is not a valid field: %s" % (key, TLPHeader.get_fields()))

    def pretty_print(self, tab = 0):
        type_str = self.tlp_type.pretty_print(tab + 1)
        flags_str = self.tlp_flags.pretty_print(tab + 1)
        dword_count = self.get_value(DWORD_COUNT)
        if not self.get_value(HAS_DATA):
            dword_count = 0

        output_str = "\n"
        output_str += "\t" * tab
        output_str += "Format/Type:\n"
        output_str += type_str
        output_str += "\n"
        output_str += "\t" * tab
        output_str += "Flags:\n"
        output_str += flags_str
        output_str += "\t" * tab
        output_str += "DWord Count:\n"
        output_str += "\t" * (tab + 1)
        output_str += "{0:<15}[{1:>5X}]: {2}\n".format("DWord Count", dword_count, DESCRIPTION_DICT[DWORD_COUNT])

        return output_str

