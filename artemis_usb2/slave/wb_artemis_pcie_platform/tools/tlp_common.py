

def print_tlp_line(name, value, description, tab = 0):
    output_str = "\t" * (tab)
    output_str += "{0:<15}[{1:>5X}]: {2}\n".format(name, value, description)
    return output_str

def print_tlp_line_hex(name, value, description, tab = 0):
    output_str = "\t" * tab
    output_str += "{0:<15}[0x{1:>03X}]: {2}\n".format(name, value, description)
    return output_str

def print_raw_packet(raw_packet, tab = 0):
    output_str = ""
    for i in range(0, len(raw_packet), 4):
        output_str += "\t" * tab
        output_str += "Address[%02X] [%04X]: %02X %02X %02X %02X\n" % (i, i / 4, raw_packet[i], raw_packet[i + 1], raw_packet[i + 2], raw_packet[i + 3])

    return output_str

