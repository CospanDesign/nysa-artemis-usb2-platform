

from tlp_memory_read_req import TLPMemoryReadRequest
from tlp_memory_write import TLPMemoryWrite
from tlp_completer_data import TLPCompleterData
from tlp_type import TLPType

HEADERS = {
    TLPMemoryReadRequest.get_type(): TLPMemoryReadRequest,
    TLPMemoryWrite.get_type(): TLPMemoryWrite,
    TLPCompleterData.get_type(): TLPCompleterData
}

def get_tlp_header(tlp_type):
    if tlp_type in HEADERS.keys():
        return HEADERS[tlp_type]
    else:
        raise AssertionError("TLP Type: %s is not implemented yet, available headers include: %s" % (tlp_type, str(HEADERS.keys())))

def get_fields(tlp_type):
    if tlp_type in HEADERS.keys():
        return HEADERS[tlp_type].get_fields()
    else:
        raise AssertionError("TLP Type: %s is not implemented yet, available headers include: %s" % (tlp_type, str(HEADERS.keys())))

def get_description(tlp_type, key):
    if tlp_type in HEADERS.keys():
        return HEADERS[tlp_type].get_description(key)
    else:
        raise AssertionError("TLP Type: %s is not implemented yet, available headers include: %s" % (tlp_type, str(HEADERS.keys())))


