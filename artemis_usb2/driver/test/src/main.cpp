#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <fcntl.h>
#include <errno.h>
#include "pcie_controller.h"


//char devname[] = "/dev/xpcie";
//char devname[] = "/sys/class/nysa_pcie/nysa_pcie0";
char devname[] = "/dev/nysa_pcie0";
int fn = -1;

#define READ_COUNT  0x04000
#define WRITE_COUNT 0x04000
//#define WRITE_COUNT 0x0100

#define READ_BUFF_SIZE 0x08000

int main(){
  int i = 0;
  unsigned char buf[READ_BUFF_SIZE];

  PCIE *pcie = new PCIE(devname);
  pcie->enable_debug(true);
  //pcie->write_register(0x00, 0x01);
  //pcie->write_command(0x08A, 0x01, 0x00);

/*
  //Read a small block of data
  pcie->read_periph_data(0x00, buf, READ_COUNT);
  for (i = 0; i < READ_COUNT; i++)
  {
    printf ("[0x%02X] 0x%02X\n", i, buf[i]);
  }
*/

  //Configure everything for a write
  for (i = 0; i < WRITE_COUNT; i++)
  {
    //printf ("[0x%02X] 0x%02X\n", i, buf[i]);
    buf[i] = i % 256;
    //buf[i] = 0x00;
  }
  pcie->write_periph_data(0x00, buf, WRITE_COUNT);

}

