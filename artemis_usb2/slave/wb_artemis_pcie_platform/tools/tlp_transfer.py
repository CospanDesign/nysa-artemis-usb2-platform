from tlp_type import TLPType
from tlp_flags import TLPFlags
from tlp_common import print_raw_packet
from tlp_header import *

ADDRESS = "address"
BUS_NUM = "bus_number"
DEVICE_NUM = "device_number"
FUNCTION_NUM = "function_number"
TAG = "tag"
REQUESTER_ID = "requester_id"
FIRST_BE = "first_be"
LAST_BE = "last_be"
DATA = "data"

DESCRIPTION_DICT = {
    ADDRESS:        "32-bit or 64-bit address",
    DEVICE_NUM:     "Device index within PCI Bus",
    BUS_NUM:        "PCI Bus Number",
    FUNCTION_NUM:   "Function of the PCI Device",
    TAG:            "Tag ID number (used with Memory Read Requests)",
    REQUESTER_ID:   "Request ID sent to the item to be read from",
    FIRST_BE:       "First Byte Enable",
    LAST_BE:        "Last Byte Enable",
    DATA:           "Packet Data"
}

TRANSFER_HEADER_FIELDS = [ADDRESS, BUS_NUM, DEVICE_NUM, FUNCTION_NUM, TAG, REQUESTER_ID, FIRST_BE, LAST_BE, DATA]

class TLPTransfer(TLPHeader):
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
        if key in TLPTransfer.get_fields():
            if key in DESCRIPTION_DICT.keys():
                return DESCRIPTION_DICT[key]
            else:
                return TLPHeader.get_description(key)
        else:
            raise AssertionError("%s could not be found, valid values are: %s" % (key, TLPTransfer.keys()))

    def __init__(self):
        super (TLPTransfer, self).__init__()
        self.data = Array('B')

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
        self.set_value(REQUESTER_ID, 0x00)
        super (TLPTransfer, self).initialize()

    def generate_raw(self):
        return super(TLPTransfer, self).generate_raw()

    def parse_raw(self, raw):
        super (TLPTransfer, self).parse_raw(raw)
        address = (raw[8] << 24) | (raw[9] << 16) | (raw[10] << 8) | raw[11]
        requester_id = (raw[4] << 8) | raw[5]
        tag = raw[6]
        lbe = (raw[7] >> 4) & 0x0F
        fbe = (raw[7] & 0xF)

        self.set_value(ADDRESS, address)
        self.set_value(REQUESTER_ID, requester_id)
        self.set_value(TAG, tag)
        self.set_value(FIRST_BE, fbe)
        self.set_value(LAST_BE, lbe)

        if len(raw[12:]) > 0:
            self.data = raw[12:]

    def set_value(self, key, value):
        if key in TLPHeader.get_fields():
            super(TLPTransfer, self).set_value(key, value)
        elif key in TRANSFER_HEADER_FIELDS:
            if key == ADDRESS:
                #print "Address: %d" % value
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
                self.requester_id = value
            if key == FIRST_BE:
                self.first_be = value
            if key == LAST_BE:
                self.last_be = value
            if key == DATA:
                self.data = value
                if len(self.data) == 0:
                    return
                while len(self.data) % 4:
                    self.data.append(0x00)

                self.set_value(DWORD_COUNT, (len(self.data) / 4))
                self.set_value("has_data", True)
        else:
            raise AssertionError("%s is not a valid field: %s" % (key, TLPHeader.get_fields()))

    def get_value(self, key):

        if key in TLPHeader.get_fields():
            return super(TLPTransfer, self).get_value(key)
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
                return self.requester_id
            if key == FIRST_BE:
                return self.first_be
            if key == LAST_BE:
                return self.last_be
            if key == DATA:
                header_size = 3
                if not self.get_value("has_data"):
                    return Array('B')
                data = self.generate_raw()
                if self.get_value("64bit"):
                    header_size = 4

                return data[(header_size * 4):]
        else:
            raise AssertionError("%s is not a valid field: %s" % (key, TLPHeader.get_fields()))

    def pretty_print(self, tab = 0):
        output_str = super(TLPTransfer, self).pretty_print(tab)
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

        if len(self.data) > 0:
            output_str += "\t" * (tab)
            output_str += "Data:\n"
            output_str += print_raw_packet(self.data, tab = tab + 1)

        return output_str


