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

from tlp_header import TLPHeader
from tlp_common import print_tlp_line_hex
#sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

TLP_TYPE = "cpld"

COMPLETER_ID = "completer_id"
REQUESTER_ID = "requester_id"
COMPLETE_STATUS = "complter_status"
BCM = "bcm"
BYTE_COUNT = "byte_count"
TAG = "tag"
LOWER_ADDRESS = "lower_address"

DESCRIPTION_DICT = {
    COMPLETER_ID: "Id of the bus that sent the completer packet",
    REQUESTER_ID: "Id of the entity that requested the data",
    COMPLETE_STATUS: "Status of read request: 000: Success, 001: Unsupported Request, 010: Config Retry, 100: Abort",
    BCM: "When a packet is broken up by a PCIX host, this bit is set with the first transaction, the 'byte count' field indiciates the size of just the first packet, not the rest",
    TAG: "Tag for the requester to locate transfer, this should match the tag from read request",
    BYTE_COUNT: "Number of bytes required to complete a packet, if done this should read 0x00 (Unless BCM is set then this will report the size of the fist packet)",
    LOWER_ADDRESS: "When a packet is broken up this field represents the lower address field of the first byte enable"
}

class TLPCompleterData(TLPHeader):

    @staticmethod
    def get_fields():
        fields = TLPHeader.get_fields()
        fields.extend(DESCRIPTION_DICT.keys())
        return fields

    @staticmethod
    def get_type():
        return TLP_TYPE

    @staticmethod
    def get_description(key):
        return TLPHeader.get_description(key)

    def __init__(self):
        super (TLPCompleterData, self).__init__()

    def initialize(self):
        super (TLPCompleterData, self).initialize()
        self.set_value("type", TLP_TYPE)
        self.set_value("has_data", True)
        self.set_value(COMPLETER_ID, 0x001)
        self.set_value(REQUESTER_ID, 0x002)
        self.set_value(COMPLETE_STATUS, 0x00)
        self.set_value(BCM, 0x00)
        self.set_value(LOWER_ADDRESS, 0x00)
        self.set_value(TAG, 0x04)
        self.set_value(BYTE_COUNT, 0x00)

    def generate_raw(self):
        raw = super (TLPCompleterData, self).generate_raw()
        completer_id = self.get_value(COMPLETER_ID)
        requester_id = self.get_value(REQUESTER_ID)
        status = self.get_value(COMPLETE_STATUS)
        bcm = self.get_value(BCM)
        tag = self.get_value(TAG)
        lower_address = self.get_value(LOWER_ADDRESS)
        byte_count = self.get_value(BYTE_COUNT)

        raw.append((completer_id >> 8) & 0xFF)
        raw.append(completer_id & 0xFF)
        value = (completer_id << 5) & 0xE
        value |= ((bcm & 0x01) << 4)
        value |= ((byte_count >> 8) & 0xF)
        raw.append(value)
        raw.append(byte_count & 0xFF)
        raw.append((requester_id >> 8) & 0xFF)
        raw.append(requester_id & 0xFF)
        raw.append(tag)
        raw.append(lower_address & 0x7F)
        return raw

    def parse_raw(self, raw):
        completer_id = (raw[4] << 8) + raw[5]
        status = (raw[6] >> 5) & 0x7
        bcm = raw[6] >> 4 & 0x01
        byte_count = ((raw[6] & 0xF) << 8) | (raw[7])
        requester_id = (raw[8] << 8) | raw[9]
        tag = raw[10]
        lower_address = raw[11] & 0x7F

        self.set_value(COMPLETER_ID, completer_id)
        self.set_value(REQUESTER_ID, requester_id)
        self.set_value(BCM, bcm)
        self.set_value(TAG, tag)
        self.set_value(BYTE_COUNT, byte_count)
        self.set_value(LOWER_ADDRESS, lower_address)
        
    def set_value(self, key, value):
        if key in super(TLPCompleterData, self).get_fields():
            super (TLPCompleterData, self).set_value(key, value)

        elif key in TLPCompleterData.get_fields():
            if key == COMPLETER_ID:
                self.completer_id = value
            if key == REQUESTER_ID:
                self.requester_id = value
            if key == COMPLETE_STATUS:
                self.complete_status = value
            if key == BCM:
                self.bcm = value
            if key == LOWER_ADDRESS:
                self.lower_address = value
            if key == TAG:
                self.tag = value
            if key == BYTE_COUNT:
                self.byte_count = value
        else:
            raise AssertionError("%s could not be found, valid values are %s" % (key, TLPCompleterData.get_fields()))

    def get_value(self, key):
        if key in super(TLPCompleterData, self).get_fields():
            return super (TLPCompleterData, self).get_value(key)

        elif key in TLPCompleterData.get_fields():
            if key == COMPLETER_ID:
                return self.completer_id
            if key == REQUESTER_ID:
                return self.requester_id
            if key == COMPLETE_STATUS:
                return self.complete_status
            if key == BCM:
                return self.bcm
            if key == LOWER_ADDRESS:
                return self.lower_address
            if key == TAG:
                return self.tag
            if key == BYTE_COUNT:
                return self.byte_count
        else:
            raise AssertionError("%s could not be found, valid values are: %s" % (key, TLPCompleterData.get_fields()))

    def pretty_print(self, tab = 0):
        output_str = super(TLPCompleterData, self).pretty_print(tab = tab)
        completer_id = self.get_value(COMPLETER_ID)
        requester_id = self.get_value(REQUESTER_ID)
        complete_status = self.get_value(COMPLETE_STATUS)
        bcm = self.get_value(BCM)
        lower_addr = self.get_value(LOWER_ADDRESS)
        tag = self.get_value(TAG)

        output_str += "\t" * tab
        output_str += "Completion Header Specific Fields\n"
        output_str += print_tlp_line_hex("Completer ID", completer_id, DESCRIPTION_DICT[COMPLETER_ID], tab + 1)
        output_str += print_tlp_line_hex("Requester ID", requester_id, DESCRIPTION_DICT[REQUESTER_ID], tab + 1)
        output_str += print_tlp_line_hex("Status", complete_status, DESCRIPTION_DICT[COMPLETE_STATUS], tab + 1)
        output_str += print_tlp_line_hex("BCM", bcm, DESCRIPTION_DICT[BCM], tab + 1)
        output_str += print_tlp_line_hex("Lower Addr", lower_addr, DESCRIPTION_DICT[LOWER_ADDRESS], tab + 1)
        output_str += print_tlp_line_hex("Tag", tag, DESCRIPTION_DICT[TAG], tab + 1)
        
        return output_str




