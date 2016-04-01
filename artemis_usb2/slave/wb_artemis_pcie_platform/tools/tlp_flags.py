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

FLAGS = {
            "tc":           {"description": "Traffic Class (Priority of packet): 0 - 7"},
            "id_order":     {"description": "ID Based Ordering: 0 - 1"},
            "relax_order":  {"description": "Relaxed Ordering: 0 - 1"},
            "no_snoop":     {"description": "Enable hardware cache coherency: 0 - 1"},
            "process_hint": {"description": "Enable post packet process hint: 0 - 1"},
            "tlp_digest":   {"description": "Enable post packet TLP Digest: 0 - 1"},
            "poisoned":     {"description": "Poison the TLP: 0 - 1"},
            "address_trans":{"description": "Address Translate: 00: untranslate, 01: translate, 10: translate, 11: reserved"}
        }

class TLPFlags(object):

    @staticmethod
    def get_fields():
        return FLAGS.keys()

    @staticmethod
    def get_description(name):
        return FLAGS[key]["description"]

    def __init__(self):
        self.initialize()

    def initialize(self):
        self.set_traffic_class(0x00)
        self.enable_tlp_processing_hint(False)
        self.enable_tlp_digest(False)
        self.enable_poisoned(False)
        self.enable_id_based_ordering(False)
        self.enable_relaxed_ordering(False)
        self.enable_no_snoop_mode(True)
        self.set_address_type(0x00)

    def get_flag_description(self, flag):
        if flag is None:
            mystr = ""
            for key in FLAGS:
                mystr += "%s: %s\n", (key, FLAGS[key]["description"])
            return mystr
        if flag not in FLAGS.keys():
            raise AssertionError("Illegal Flag: %s, possible flags: %s" % (flag, str(FLAGS.keys())))

        return "%s: %s" % (flag, FLAGS[flag]["description"])

    #Traffic Class
    def set_traffic_class(self, tc):
        if (tc > 7) or (tc < 0):
            raise AssertionError ("Illegal Traffic Class: %d, (can only be 0 - 7)" % tc)
        self.traffic_class = tc

    def get_traffic_class(self):
        return self.traffic_class

    #Processing Hint
    def enable_tlp_processing_hint(self, enable):
        self.tlp_processing_hint = enable

    def is_tlp_processing_hint(self):
        return self.tlp_processing_hint

    #TLP Digest
    def enable_tlp_digest(self, enable):
        self.tlp_digest = enable

    def is_tlp_digest_enabled(self):
        return self.tlp_digest

    #Poisoned Bit
    def enable_poisoned(self, enable):
        self.poisoned_bit = enable

    def is_poisoned(self):
        return self.poisoned_bit

    #ID based ordering
    def enable_id_based_ordering(self, enable):
        self.id_based_ordering = enable

    def is_id_based_ordering(self):
        return self.id_based_ordering

    #Relaxed Ordering
    def enable_relaxed_ordering(self, enable):
        self.relaxed_ordering = enable

    def is_relaxed_ordering(self):
        return self.relaxed_ordering

    #No Snoop
    def enable_no_snoop_mode(self, enable):
        self.no_snoop = enable

    def is_no_snoop_mode(self):
        return self.no_snoop

    def set_address_type(self, at):
        if (at < 0) or (at > 3):
            raise AssertionError("Addres type cannot be: %d, must be 00, 01, 10 or 11")
        self.address_type = at

    def get_address_type(self):
        return self.address_type

    def generate_raw(self):
        tc = self.get_traffic_class()
        id_ord = (1 if self.is_id_based_ordering() else 0)
        th = (1 if self.is_tlp_processing_hint() else 0)
        td = (1 if self.is_tlp_digest_enabled() else 0)
        ep = (1 if self.is_poisoned() else 0)
        ro = (1 if self.is_relaxed_ordering() else 0)
        ns = (1 if self.is_no_snoop_mode() else 0)
        at = self.get_address_type()

        flags = 0x00
        flags |= tc << 10
        flags |= id_ord << 8
        flags |= th << 6
        flags |= td << 5
        flags |= ep << 4
        flags |= ro << 3
        flags |= ns << 2
        flags |= at
        return flags

    def parse_flags(self, flags):
        at = flags & 0x03
        flags = flags >> 2
        ns = flags & 0x01
        flags = flags >> 1
        ro = flags & 0x01
        flags = flags >> 1
        ep = flags & 0x01
        flags = flags >> 1
        td = flags & 0x01
        flags = flags >> 1
        th = flags & 0x01
        flags = flags >> 2
        id_ord = flags & 0x01
        flags = flags >> 2
        tc = flags & 0x03

        self.set_traffic_class(tc)
        self.enable_tlp_processing_hint(th)
        self.enable_tlp_digest(td)
        self.enable_poisoned(ep)
        self.enable_id_based_ordering(id_ord)
        self.enable_relaxed_ordering(ro)
        self.enable_no_snoop_mode(ns)
        self.set_address_type(at)

    def get_value(self, name):
        if name == "tc":
            return self.get_traffic_class()
        elif name == "id_order":
            return self.is_id_based_ordering()
        elif name == "relax_order":
            return self.is_relaxed_ordering()
        elif name == "no_snoop":
            return self.is_no_snoop_mode()
        elif name == "process_hint":
            return self.is_tlp_processing_hint()
        elif name == "tlp_digest":
            return self.is_tlp_digest_enabled()
        elif name == "poisoned":
            return self.is_poisoned()
        elif name == "address_trans":
            return self.get_address_type()
        else:
            raise AssertionError("%s is not a valid field: Vaild fields: %s" % (name, TLPFlags.get_fields()))

    def set_value(self, name, value):
        if name == "tc":
            return self.set_traffic_class(value)
        elif name == "id_order":
            return self.enable_id_based_ordering(value)
        elif name == "relax_order":
            return self.enable_relaxed_ordering(value)
        elif name == "no_snoop":
            return self.enable_no_snoop_mode(value)
        elif name == "process_hint":
            return self.enable_tlp_processing_hint(value)
        elif name == "tlp_digest":
            return self.enable_tlp_digest(value)
        elif name == "poisoned":
            return self.enable_poisoned(value)
        elif name == "address_trans":
            return self.set_address_type(value)
        else:
            raise AssertionError("%s is not a valid field: Vaild fields: %s" % (name, TLPFlags.get_fields()))

    def pretty_print(self, tab=0):
        output_str = ""
        for key in FLAGS:
            for i in range(tab):
                output_str += "\t"
            output_str += "{0:<15}[{1:>5}]: {2:<5}\n".format(key, self.get_value(key), FLAGS[key]["description"])
        return output_str


