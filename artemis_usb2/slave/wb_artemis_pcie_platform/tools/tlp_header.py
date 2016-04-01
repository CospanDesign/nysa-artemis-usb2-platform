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

ADDRESS = "address"
BUS_NUM = "bus_number"
DEVICE_NUM = "device_number"
FUNCTION_NUM = "function_number"
DWORD_COUNT = "dword_count"
TAG = "tag"
REQUESTER_ID = "requester_id"
FIRST_BE = "first_be"
LAST_BE = "last_be"
HAS_DATA = "has_data"

DESCRIPTION_DICT = {
    DEVICE_NUM:     "Device index within PCI Bus",
    BUS_NUM:        "PCI Bus Number",
    FUNCTION_NUM:   "Function of the PCI Device",
    DWORD_COUNT:    "Number of 32-bit values to transfer",
    TAG:            "Tag ID number (used with requester ID",
    REQUESTER_ID:   "Request ID sent to the item to be read from",
    FIRST_BE:       "First Byte Enable",
    LAST_BE:        "Last Byte Enable",
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
            self.tlp_type.get_value(key)
        elif key in TLPFlags.get_fields():
            self.tlp_flags.get_value(key)
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

TRANSFER_HEADER_FIELDS = [ADDRESS, BUS_NUM, DEVICE_NUM, FUNCTION_NUM, TAG, REQUESTER_ID, FIRST_BE, LAST_BE]

class TLPTransferHeader(TLPHeader):
    @staticmethod
    def get_fields():
        fields =[]
        fields.extend(TLPHeader.get_fields())
        fields.extend(TRANSFER_HEADER_FIELDS)
        return fields

    @staticmethod
    def get_type():
        raise AssertionError("This should be set by subclass")

    @staticmethod
    def get_description(key):
        if key in TLPTransferHeader.get_fields():
            if key in DESCRIPTION_DICT.keys():
                return DESCRIPTION_DICT[key]
            else:
                return TLPHeader.get_description(key)
        else:
            raise AssertionError("%s could not be found, valid values are: %s" % (key, TLPTransferHeader.keys()))

    def __init__(self):
        super (TLPTransferHeader, self).__init__()

    def initialize(self):
        self.set_value(ADDRESS, 0x01234567)
        self.set_value(BUS_NUM, 0x03)
        self.set_value(DEVICE_NUM, 0x00)
        self.set_value(FUNCTION_NUM, 0x00)
        self.set_value(DWORD_COUNT, 0x01)
        self.set_value(TAG, 0x00)
        self.set_value(FIRST_BE, 0xF)
        self.set_value(LAST_BE, 0xF)
        self.set_value(HAS_DATA, False)
        super (TLPTransferHeader, self).initialize()

    def generate_raw(self):
        raw = super(TLPTransferHeader, self).generate_raw()
        #Generate the address
        requester_id = self.get_value(REQUESTER_ID)
        tag = self.get_value(TAG)
        dword_count = self.get_value(DWORD_COUNT)
        byte_enable = 0x00
        first_byte_enable = self.get_value(FIRST_BE)
        last_byte_enable = self.get_value(LAST_BE)
        address = self.get_value(ADDRESS)
        if not self.get_value(HAS_DATA):
            dword_count = 0

        if dword_count == 0:
            first_byte_enable = 0x00
            last_byte_enable = 0x00
        if dword_count == 1:
            last_byte_enable = 0x00

        #Add Next Line
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
        return raw

    def parse_raw(self, raw):
        pass

    def get_requester_id(self):
        #Not sure how to generat this yet
        self.requester_id = 0x00
        return self.requester_id

    def set_value(self, key, value):
        if key in TLPHeader.get_fields():
            super(TLPTransferHeader, self).set_value(key, value)
        elif key in TRANSFER_HEADER_FIELDS:
            if key == ADDRESS:
                print "Address: %d" % value
                self.address = value
            if key == BUS_NUM:
                self.bus_num = value
            if key == DEVICE_NUM:
                self.device_num = value
            if key == FUNCTION_NUM:
                self.function_num = value
            if key == TAG:
                self.tag = value
            if key == REQUESTER_ID:
                raise AssertionError("%s cannot be set by user", key)
            if key == FIRST_BE:
                self.first_be = value
            if key == LAST_BE:
                self.last_be = value
        else:
            raise AssertionError("%s is not a valid field: %s" % (key, TLPHeader.get_fields()))

    def get_value(self, key):
        if key in TLPHeader.get_fields():
            return super(TLPTransferHeader, self).get_value(key)
        elif key in TRANSFER_HEADER_FIELDS:
            if key == ADDRESS:
                return self.address
            if key == BUS_NUM:
                return self.bus_num
            if key == DEVICE_NUM:
                return self.device_num
            if key == FUNCTION_NUM:
                return self.function_num
            if key == TAG:
                return self.tag
            if key == REQUESTER_ID:
                return self.get_requester_id()
            if key == FIRST_BE:
                return self.first_be
            if key == LAST_BE:
                return self.last_be
        else:
            raise AssertionError("%s is not a valid field: %s" % (key, TLPHeader.get_fields()))

    def pretty_print(self, tab = 0):
        output_str = super(TLPTransferHeader, self).pretty_print(tab)
        requester_id = self.get_value(REQUESTER_ID)
        tag = self.get_value(TAG)
        dword_count = self.get_value(DWORD_COUNT)
        byte_enable = 0x00
        first_byte_enable = self.get_value(FIRST_BE)
        last_byte_enable = self.get_value(LAST_BE)
        address = self.get_value(ADDRESS)
        if not self.get_value(HAS_DATA):
            dword_count = 0

        if dword_count == 0:
            first_byte_enable = 0x00
            last_byte_enable = 0x00
        if dword_count == 1:
            last_byte_enable = 0x00

        output_str += "\n"
        output_str += "\t" * (tab)
        output_str += "Memory/IO Transfer Specific Values:"
        output_str += "\n"

        output_str += "\t" * (tab + 1)
        output_str += "{0:<15}[{1:>5X}]: {2}\n".format("Requester ID", requester_id, DESCRIPTION_DICT[REQUESTER_ID])
        output_str += "\t" * (tab + 1)
        output_str += "{0:<15}[{1:>5X}]: {2}\n".format("Tag", tag, DESCRIPTION_DICT[TAG])
        output_str += "\t" * (tab + 1)
        output_str += "{0:<15}[{1:>5X}]: {2}\n".format("Last Byte En", last_byte_enable, DESCRIPTION_DICT[LAST_BE])
        output_str += "\t" * (tab + 1)
        output_str += "{0:<15}[{1:>5X}]: {2}\n".format("First Byte En", first_byte_enable, DESCRIPTION_DICT[FIRST_BE])

        output_str += "\t" * (tab + 1)
        if self.get_value("64bit"):
            output_str += "{0:<8}{1:>7}[0x{2:016X}]: {3}\n".format("Address", "64 bit", address, DESCRIPTION_DICT[ADDRESS])
        else:
            output_str += "{0:<8}{1:>7}[0x{2:08X}]: {3}\n".format("Address", "32 bit", address, DESCRIPTION_DICT[ADDRESS])
        return output_str


