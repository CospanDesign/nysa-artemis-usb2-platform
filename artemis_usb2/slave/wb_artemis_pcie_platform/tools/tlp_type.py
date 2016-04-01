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

TYPES = {   "mrd":      {"value":0x00, "description": "Memory Read"                 },
            "mrdlk":    {"value":0x01, "description": "Memory Read with Lock"       },
            "mwr":      {"value":0x00, "description": "Memory Write"                },
            "iord":     {"value":0x02, "description": "I/O Read Request"            },
            "iowr":     {"value":0x02, "description": "I/O Write Request"           },
            "cfgrd0":   {"value":0x04, "description": "Configuration Read Type 0"   },
            "cfgwr0":   {"value":0x04, "description": "Configuration Write Type 0"  },
            "cfgrd1":   {"value":0x05, "description": "Configuration Read Type 1"   },
            "cfgwr1":   {"value":0x05, "description": "Configuration Write Type 1"  },
            "msg":      {"value":0x10, "description": "Message"                     },
            "msgd":     {"value":0x10, "description": "Message with Data"           },
            "cpl":      {"value":0x0A, "description": "Complete without Data"       },
            "cpld":     {"value":0x0A, "description": "Complete with Data"          },
            "cplk":     {"value":0x0B, "description": "Complete with lock"          },
            "cpldlk":   {"value":0x0B, "description": "Complete with Data and Lock" },
            "fetchadd": {"value":0x0C, "description": "Fetch and Add (Atomic)"      },
            "swap":     {"value":0x0D, "description": "Swap (Atomic)"               },
            "cas":      {"value":0x0E, "description": "Compare and Swap (Atomic)"   },
            "lprfx":    {"value":0x00, "description": "Local TLP Prefix"            },
            "eprfx":    {"value":0x10, "description": "End to End Prefix"           },
        }

class TLPType(object):

    @staticmethod
    def get_fields():
        return ["type", "format", "64bit", "prefix", "subfield", "data_available"]

    @staticmethod
    def get_names():
        return TYPES.keys()

    @staticmethod
    def get_description(name = None):
        if name not in TYPES.keys():
            raise AssertionError("%s is not in %s" % (name, TLPType.get_names()))

        return TYPES[name]["description"]

    def __init__(self):
        self.initialize()

    def initialize(self):
        self.tlp_type = "mwr"
        self.range_64bit = False
        self.subfield = 0x00
        self.tlp_prefix = 0x00

    def set_type_name(self, name):
        if name not in TYPES.keys():
            raise AssertionError("%s is not in %s" % (name, TLPType.get_names()))
        self.tlp_type = name

    def get_type_name(self):
        return self.tlp_type

    def enable_64bit(self, enable):
        if enable:
            self.range_64bit = True
        else:
            self.range_64bit = False

    def is_64bit_enabled(self):
        return self.range_64bit

    def is_data_in_packet(self):
        fmt = self.get_format()
        if fmt & 0x02:
            return True
        return False

    def get_format(self):
        t = self.tlp_type
        b = self.range_64bit

        if t == "mrd":
            if b: return 0x01
            return 0x00
        if t == "mrdlk":
            if b: return 0x01
            return 0x00
        if t == "mwr":
            if b: return 0x03
            return 0x02
        if t == "iord":
            return 0x00
        if t == "iowr":
            return 0x02
        if t == "cfgrd0":
            return 0x00
        if t == "cfgwr0":
            return 0x02
        if t == "cfgrd1":
            return 0x00
        if t == "cfgwr1":
            return 0x02
        if t == "msg":
            return 0x01
        if t == "msgd":
            return 0x03
        if t == "cpl":
            return 0x00
        if t == "cpld":
            return 0x02
        if t == "cpllk":
            return 0x00
        if t == "cpldlk":
            return 0x02
        if t == "fetchadd":
            if b: return 0x03
            return 0x02
        if t == "swap":
            if b: return 0x03
            return 0x02
        if t == "cas":
            if b: return 0x03
            return 0x02
        if t == "lprfx":
            return 0x04
        if t == "eprfx":
            return 0x04

    def set_subfield(self, subfield):
        self.subfield = subfield

    def get_subfield(self):
        return self.subfield

    def set_prefix(self, prefix):
        self.prefix = prefix

    def get_prefix(self):
        return self.prefix

    def generate_raw(self):
        f = self.get_format()
        t = TYPES[self.tlp_type]["value"]
        if self.tlp_type == "msg" or self.tlp_type == "msgd":
            t |= self.subfield
        if self.tlp_type == "lprfx" or self.tlp_type == "eprfx":
            t |= self.prefix

        return (0xFF) & ((f << 5) | t)

    @staticmethod
    def parse_64bit(tlp_fmt_type_byte):
        f = 0xFF & tlp_fmt_type_byte
        f = 0xFF & f >> 5
        if (f & 0x01) > 0:
            return True
        return False

    @staticmethod
    def parse_type(tlp_fmt_type_byte):
        f = 0xFF & tlp_fmt_type_byte
        t = 0x1F & f
        f = (0xFF) & f >> 5
        if f == 0x04:
            if (t & 0x10) > 0: return "lprfx"
            return "eprfx"
        if ((t & 0x10) > 0):
            if (f & 0x2) > 0: return "msgd"
            return "msg"
        if t == TYPES["mrd"]["value"]:
            if (f & 0x2) > 0: return "mwr"
            return "mrd"
        if t == TYPES["mrdlk"]["value"]:
            return "mrdlk"
        if t == TYPES["iord"]["value"]:
            if (f & 0x2) > 0: return "iowr"
            return "iord"
        if t == TYPES["cfgrd0"]["value"]:
            if (f & 0x2) > 0: return "cfgwr0"
            return "cfgrd0"
        if t == TYPES["cfgrd1"]["value"]:
            if (f & 0x2) > 0: return "cfgwr1"
            return "cfgrd1"
        if t == TYPES["cpl"]["value"]:
            if (f & 0x2) > 0: return "cpld"
            return "cpl"
        if t == TYPES["cplk"]["value"]:
            if (f & 0x2) > 0: return "cpdlk"
            return "cplk"
        if t == TYPES["fetchadd"]["value"]:
            return "fetchadd"
        if t == TYPES["swap"]["value"]:
            return "swap"
        if t == TYPES["cas"]["value"]:
            return "cas"

    def set_value(self, name, value):
        if name == "type":
            self.set_type_name(value)
        elif name == "format":
            raise AssertionError("Cannot set format manually")
        elif name == "64bit":
            self.enable_64bit(value)
        elif name == "prefix":
            self.set_prefix(value)
        elif name == "subfield":
            self.set_subfield(value)
        else:
            raise AssertionError("\"%s\" is not a valid field: Vaild fields: %s" % (name, TLPType.get_fields()))

    def get_value(self, name):
        if name == "type":
            return self.get_type_name()
        elif name == "format":
            return self.get_format()
        elif name == "64bit":
            return self.is_64bit_enabled()
        elif name == "prefix":
            return self.get_prefix()
        elif name == "subfield":
            return self.get_subfield()
        elif name == "data_available":
            return self.is_data_in_packet()
        else:
            raise AssertionError("\"%s\" is not a valid field: Vaild fields: %s" % (name, TLPType.get_fields()))

    def pretty_print_format(self, tab = 0):
        output_str = ""
        fmt = self.get_value("format")
        if fmt & 0x04:
            for i in range(tab):
                output_str += "\t"
            output_str += "TLP Prefix\n"

        if fmt & 0x02:
            for i in range(tab):
                output_str += "\t"
            output_str += "Data\n"

        if fmt & 0x01:
            for i in range(tab):
                output_str += "\t"
            output_str += "64-bit Address\n"
        return output_str

    def pretty_print(self, tab=0):
        output_str = ""
        t = self.get_value("type")
        for i in range(tab):
            output_str += "\t"
        output_str += "Packet Format\n"
        output_str += self.pretty_print_format(tab = tab + 1)

        for i in range(tab):
            output_str += "\t"
        output_str += "TLP Type: %s: %s" % (t, TYPES[t]["description"])
        if t == "msg" or t == "msgd":
            for i in range(tab):
                output_str += "\t"
            output_str += self.get_value("subfield")

        if t == "lprfx" or t == "eprfx":
            for i in range(tab):
                output_str += "\t"
            output_str += self.get_value("prefix")

        return output_str










