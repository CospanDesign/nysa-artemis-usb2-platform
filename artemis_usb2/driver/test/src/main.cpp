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

#define ITEM_COUNT 12

int main(){
  PCIE *pcie = new PCIE(devname);
  pcie->enable_debug(true);
  //pcie->write_register(0x00, 0x01);
  pcie->write_command(0x08A, 0x01, 0x00);
}

