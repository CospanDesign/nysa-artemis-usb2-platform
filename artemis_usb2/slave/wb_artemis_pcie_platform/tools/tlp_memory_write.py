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

from tlp_header import TLPTransferHeader
#sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir)))

TLP_TYPE = "mwr"


class TLPMemoryWrite(TLPTransferHeader):

    @staticmethod
    def get_fields():
        return TLPTransferHeader.get_fields()

    @staticmethod
    def get_type():
        return TLP_TYPE

    @staticmethod
    def get_description(key):
        return TLPTransferHeader.get_description(key)

    def __init__(self):
        super (TLPMemoryWrite, self).__init__()

    def initialize(self):
        super (TLPMemoryWrite, self).initialize()
        self.set_value("type", TLP_TYPE)
        self.set_value("has_data", True)
        self.set_value("dword_count", 1)

    def generate_raw(self):
        return super (TLPMemoryWrite, self).generate_raw()

    def set_value(self, key, value):
        super (TLPMemoryWrite, self).set_value(key, value)

    def get_value(self, key):
        return super (TLPMemoryWrite, self).get_value(key)

    def pretty_print(self):
        return super(TLPMemoryWrite, self).pretty_print()



