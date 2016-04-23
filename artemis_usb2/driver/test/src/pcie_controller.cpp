
#include <stdio.h>
#include <fcntl.h>
#include "pcie_controller.h"



#include <stdlib.h>
#include <unistd.h>
#include <termios.h>

//Constructor
PCIE::PCIE (char * filename)
{
  debug = false;
  fn = open(filename, O_RDWR);
}

PCIE::~PCIE ()
{
}

void PCIE::enable_debug(bool enable)
{
  debug = enable;
}

void PCIE::write_register(unsigned int address, unsigned int value)
{
  char write_data[8];

  write_data[0]  = (0xFF & (address >> 24));
  write_data[1]  = (0xFF & (address >> 16));
  write_data[2]  = (0xFF & (address >>  8));
  write_data[3]  = (0xFF & (address >>  0));

  write_data[4]  = (0xFF & (value >> 24));
  write_data[5]  = (0xFF & (value >> 16));
  write_data[6]  = (0xFF & (value >>  8));
  write_data[7]  = (0xFF & (value >>  0));

  write(fn, write_data, 8);

  if (debug)
  {
    for(int i=0; i < 8; i=i + 4)
    {
      unsigned int write_word = ((write_data[i] << 24) + (write_data[i + 1] << 16) + (write_data[i + 2] << 8) + (write_data[i + 3]));
      printf ("[%d]\t\t-> 0x%08X\n", i, write_word);
    }
  }
}

void PCIE::write_command(unsigned int address, unsigned int value, unsigned int device_address)
{
  char write_data[12];

  write_data[0]  = (0xFF & (address >> 24));
  write_data[1]  = (0xFF & (address >> 16));
  write_data[2]  = (0xFF & (address >>  8));
  write_data[3]  = (0xFF & (address >>  0));

  write_data[4]  = (0xFF & (value >> 24));
  write_data[5]  = (0xFF & (value >> 16));
  write_data[6]  = (0xFF & (value >>  8));
  write_data[7]  = (0xFF & (value >>  0));

  write_data[8]  = (0xFF & (device_address >> 24));
  write_data[9]  = (0xFF & (device_address >> 16));
  write_data[10] = (0xFF & (device_address >>  8));
  write_data[11] = (0xFF & (device_address >>  0));

  write(fn, write_data, 12);

  if (debug)
  {
    for(int i=0; i < 12; i=i + 4)
    {
      unsigned int write_word = ((write_data[i] << 24) | (write_data[i + 1] << 16) | (write_data[i + 2] << 8) | (write_data[i + 3]));
      printf ("[%d]\t\t-> 0x%08X\n", i, write_word);
    }
  }
}
