
import sys
import os
import string
import time
import argparse
from array import array as Array

from pyftdi.pyftdi.ftdi import Ftdi

from fifo.fifo import FifoController
from spi_flash import serial_flash_manager
from bitbang.bitbang import BitBangController

from nysa.host.nysa import NysaError


def upload(vendor, product, serial_number, filepath, status):
        """
        Read a binary file found at filepath and write the binary image into the Flash

        Args:
            vendor (int): Vendor ID of the USB Device
            product (int): Product ID of the USB Device
            serial_number (int): Serial Number of the device
            filepath (string): Path to the binary file to upload
            status (Status Object): Status object, could be left blank if status is
                not needed

        Return:
            Nothing

        Raises:
            USBError
        """
        s = status
        binf = ""

        f = open(filepath, "r")
        binf = f.read()
        f.close()

        if s: s.Debug("Found file at: %s, read binary file" % filepath)

        set_debug_mode(vendor, product, serial_number)
        manager = serial_flash_manager.SerialFlashManager(vendor, product, 2)
        flash = manager.get_flash_device()

        if s: s.Info("Found: %s" % str(flash))
        if s: s.Info("Erasing the SPI flash device, this can take a minute or two...")
        flash.bulk_erase()
        if s: s.Info("Flash erased, writing binary image to PROM")
        flash.write(0x00, binf)
        if s: s.Info("Reading back the binary flash")
        binf_rb = flash.read(0x00, len(binf))
        if s: s.Info("Verifying the data read back is correct")
        binf_str = binf_rb.tostring()
        del flash
        del manager

        if binf_str != binf:
            if s: s.Error("Data read back is not the same!")

        if s: s.Info("Verification passed!")
        set_sync_fifo_mode(vendor, product, serial_number)

def program(vendor, product, serial_number, status = None):
        """
        Send a program signal to the Artemis

        Args:
            vendor (int): Vendor ID of the USB Device
            product (int): Product ID of the USB Device
            serial_number (int): Serial Number of the device
            status (Status Object): Status object, could be left blank if status is
                not needed

        Return:
            Nothing

        Raises:
            USBError

        """
        bbc = BitBangController(vendor, product, 2)
        bbc.set_pins_to_input()
        if status: status.Debug("Set signals to output")
        bbc.set_pins_to_output()
        bbc.program_high()
        time.sleep(.5)
        if status: status.Debug("Program low for .2 seconds")
        bbc.program_low()
        time.sleep(.2)
        if status: status.Debug("Program high for")
        bbc.program_high()
        bbc.pins_on()
        if status: status.Debug("Set signals to inputs")
        bbc.set_pins_to_input()

def ioctl(ftdi, name, arg = None, status = None):
        pass

def reset(ftdi, status = None):
        pass

def list_ioctl(status = None):
        pass

def set_sync_fifo_mode(vendor, product, serial_numbe):
    """
    Change the mode of the FIFO to a synchronous FIFO

    Args:
        Nothing

    Returns:
        Nothing

    Raises:
        Nothing

    """
    fifo = FifoController(vendor, product)
    fifo.set_sync_fifo()

def set_debug_mode(vendor, product, serial_number):
    """
    Change the mode of the FIFO to a asynchronous FIFO

    Args:
        Nothing

    Returns:
        Nothing

    Raises:
        Nothing
    """
    fifo = FifoController(vendor, product)
    fifo.set_async_fifo()

class Controller(object):

    def __init__(self, dev = None, vendor_id = 0x0403, product_id = 0x8531, status = None):
        super (Controller, self).__init__()

        self.vendor = vendor_id
        self.product = product_id
        self.s = status

    def upload(self, filepath):
        """
        Write a binary file to the the SPI Prom

        Args:
            filepath (String): Path to FPGA Binary (bin) image

        Returns (boolean):
            True: Successfully programmed
            False: Failed to program

        Raises:
            IOError:
                Failed to open binary file
        """
        binf = ""

        f = open(filepath, "r")
        binf = f.read()
        f.close()
        #Allow the users to handle File Errors

        #Open the SPI Flash Device
        manager = serial_flash_manager.SerialFlashManager(self.vendor, self.product, 2)
        flash = manager.get_flash_device()

        #Print out the device was found
        if self.s: self.s.Info("Found: %s" % str(flash))

        #Erase the flash
        if self.s: self.s.Info("Erasing the SPI Flash device, this can take a minute or two...")
        flash.bulk_erase()
        #Write the binary file
        if self.s: self.s.Info("Flash erased, writing binary image to PROM")
        flash.write(0x00, binf)

        #Verify the data was read
        binf_rb = flash.read(0x00, len(binf))
        binf_str = binf_rb.tostring()

        del flash
        del manager

        if binf_str != binf:
            raise NysaError("Image Verification Failed!, data written is not the same as data read")

    def program(self):
        """
        Send a program signal to the board, the FPGA will attempt to read the
        binary image file from the SPI prom. If successful the 'done' LED will
        illuminate

        Args:
            Nothing

        Returns:
            Nothing

        Raises:
            Nothing
        """
        bbc = BitBangController(self.vendor, self.product, 2)
        if self.s: self.s.Important("Set signals to input")
        bbc.set_pins_to_input()
        bbc.set_pins_to_output()
        bbc.program_high()
        time.sleep(.5)
        bbc.program_low()
        time.sleep(.2)
        bbc.program_high()
        bbc.pins_on()
        bbc.set_pins_to_input()

    def read_bin_file(self, filepath):
        """
        Read the binary image from the SPI Flash

        Args:
            filepath (String): Path to the filepath where the SPI image will
                be written to

        Returns:
            Nothing

        Raises:
            IOError:
                Problem openning file to write to
        """
        manager = serial_flash_manager.SerialFlashManager(self.vendor, self.product, 2)
        flash = manager.get_flash_device()

        #Don't know how long the binary file is so we need to read the entire
        #Image

        binf_rb = flash.read(0x00, len(flash))
        f = open(filepath, "w")
        binf_rb.tofile(f)
        f.close()

    def reset(self):
        """
        Send a reset signal to the board, this is the same as pressing the
        'reset' button

        Args:
            Nothing

        Returns:
            Nothing

        Raises:
            Nothing
        """
        bbc = BitBangController(self.vendor, self.product, 2)
        bbc.set_soft_reset_to_output()
        bbc.soft_reset_high()
        time.sleep(.2)
        bbc.soft_reset_low()
        time.sleep(.2)
        bbc.soft_reset_high()
        bbc.pins_on()
        bbc.set_pins_to_input()

    def set_sync_fifo_mode(self):
        """
        Change the mode of the FIFO to a synchronous FIFO

        Args:
            Nothing

        Returns:
            Nothing

        Raises:
            Nothing

        """
        fifo = FifoController(self.vendor, self.product)
        fifo.set_sync_fifo()

    def set_debug_mode(self):
        """
        Change the mode of the FIFO to a asynchronous FIFO

        Args:
            Nothing

        Returns:
            Nothing

        Raises:
            Nothing
        """
        fifo = FifoController(self.vendor, self.product)
        fifo.set_async_fifo()

    def open_dev(self):
        """_open_dev

        Open an FTDI Communication Channel

        Args:
            Nothing

        Returns:
            Nothing

        Raises:
            Exception
        """
        self.dev = Ftdi()
        frequency = 30.0E6
        latency  = 4
        #Ftdi.add_type(self.vendor, self.product, 0x700, "ft2232h")
        self.dev.open(self.vendor, self.product, 0)

        #Drain the input buffer
        self.dev.purge_buffers()

        #Reset
        #Enable MPSSE Mode
        self.dev.set_bitmode(0x00, Ftdi.BITMODE_SYNCFF)


        #Configure Clock
        frequency = self.dev._set_frequency(frequency)

        #Set Latency Timer
        self.dev.set_latency_timer(latency)

        #Set Chunk Size
        self.dev.write_data_set_chunksize(0x10000)
        self.dev.read_data_set_chunksize(0x10000)

        #Set the hardware flow control
        self.dev.set_flowctrl('hw')
        self.dev.purge_buffers()

    def ioctl(self, name, arg = None):
        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)

    def list_ioctl(self):
        raise AssertionError("%s not implemented" % sys._getframe().f_code.co_name)


