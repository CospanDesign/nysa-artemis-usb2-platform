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

from array import array as Array

from tlp_header_factory import get_tlp_header
from tlp_header_factory import get_fields
from tlp_header_factory import get_description

from tlp_type import TLPType


class TLPManager(object):

    def __init__(self, tlp_type = "mrd"):
        self.tlp = {}
        self.initialize(tlp_type)

    def initialize(self, tlp_type):
        self.header = get_tlp_header(tlp_type)()

    def generate_raw(self):
        raw = self.header.generate_raw()
        return raw

    def parse_raw(self, raw):
        tlp_64bit = TLPType.parse_64bit(raw[0])
        tlp_type = TLPType.parse_type(raw[0])
        self.initialize(tlp_type)
        self.header.set_value("64bit", tlp_64bit)
        self.header.parse_raw(raw)

    def set_value(self, key, value):
        if key == "type":
            self.initialize(value)
        #elif key in get_fields(self.header.get_value("type")):
        elif key in self.header.get_fields():
            self.header.set_value(key, value)
        else:
            raise AssertionError("Failed to find type: %s" % key)

    def get_value(self, key):
        if key in self.header.get_fields():
            return self.header.get_value(key)
        raise AssertionError("Failed to find type: %s" % key)

    def get_description(self, key):
        get_description(self.header.get_value("type"), key)

    def pretty_print(self):
        output_str = self.header.pretty_print()
        print output_str


