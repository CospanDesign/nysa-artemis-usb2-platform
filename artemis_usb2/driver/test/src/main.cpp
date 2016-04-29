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

#define ITEM_COUNT 0x4000


#define READ_BUFF_SIZE 0x08000

int main(){
  int i = 0;
  unsigned char buf[READ_BUFF_SIZE];

  PCIE *pcie = new PCIE(devname);
  pcie->enable_debug(true);
  //pcie->write_register(0x00, 0x01);
  //pcie->write_command(0x08A, 0x01, 0x00);

  //Read a small block of data
  pcie->read_periph_data(0x00, buf, ITEM_COUNT);
  for (i = 0; i < ITEM_COUNT; i++)
  {
    printf ("[0x%02X] 0x%02X\n", i, buf[i]);
  }

}

