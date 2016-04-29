
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>

#include "pcie_controller.h"

#define HDR_STATUS_BUF_ADDR   0x000
#define HDR_BUFFER_READY      0x001
#define HDR_WRITE_BUF_A_ADDR  0x002
#define HDR_WRITE_BUF_B_ADDR  0x003
#define HDR_READ_BUF_A_ADDR   0x004
#define HDR_READ_BUF_B_ADDR   0x005
#define HDR_BUFFER_SIZE       0x006
#define HDR_PING_VALUE        0x007
#define HDR_DEV_ADDR          0x008


#define COMMAND_RESET         0x080
#define PERIPHERAL_WRITE      0x081
#define PERIPHERAL_WRITE_FIFO 0x082
#define PERIPHERAL_READ       0x083
#define PERIPHERAL_READ_FIFO  0x084
#define MEMORY_WRITE          0x085
#define MEMORY_READ           0x086
#define DMA_WRITE             0x087
#define DMA_READ              0x088
#define PING                  0x089
#define READ_CONFIG           0x08A

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

ssize_t PCIE::read_periph_data(unsigned int address, unsigned char *buf, unsigned int count)
{
  //FPGA Speaks in 32-bit values so when asking for a size, make sure to specify the size in dwords
	write_command(PERIPHERAL_READ, count, address);
	return read(fn, buf, count);
}
