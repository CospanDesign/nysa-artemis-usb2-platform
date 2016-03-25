/*
//--------------------------------------------------------------------------------
//--
//-- This file is owned and controlled by Xilinx and must be used solely
//-- for design, simulation, implementation and creation of design files
//-- limited to Xilinx devices or technologies. Use with non-Xilinx
//-- devices or technologies is expressly prohibited and immediately
//-- terminates your license.
//--
//-- Xilinx products are not intended for use in life support
//-- appliances, devices, or systems. Use in such applications is
//-- expressly prohibited.
//--
//--            **************************************
//--            ** Copyright (C) 2006, Xilinx, Inc. **
//--            ** All Rights Reserved.             **
//--            **************************************
//--
//--------------------------------------------------------------------------------
//-- Filename: met.cpp
//--
//-- Description:
//--
//-- Sample memory endpoint test program for the XPCIE device driver.
//--
//--
//--
//--
//--
//--
//--------------------------------------------------------------------------------
*/

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

char devname[] = "/dev/xpcie";
int fn = -1;

#define ITEM_COUNT 4

int main(){
  int i, j;
  bool fail = false;
  int ret;

  char* devfilename = devname;
  fn = open(devfilename, O_RDWR);
  char write_data[ITEM_COUNT];
  char read_data[ITEM_COUNT];

  if ( fn < 0 )  {
    printf("Error opening device file\n");
    return -1;
  }

  for(i=0; i < ITEM_COUNT; i++){
    //write_data[i] = rand();
    write_data[i] = i % 256;
  }

  ret = write(fn, write_data, ITEM_COUNT);
  //ret = read(fn, read_data, ITEM_COUNT);

  for(i=0; i < ITEM_COUNT; i=i + 4) {
      unsigned int write_word = ((write_data[i] << 24) + (write_data[i + 1] << 16) + (write_data[i + 2] << 8) + (write_data[i + 3]));
  //    unsigned int read_word =  ((read_data[i]  << 24) +  (read_data[i + 1] << 16) +  (read_data[i + 2] << 8) +  (read_data[i + 3]));
  //    printf ("[%d]\t\t-> 0x%08X != 0x%08X\n", i, write_word, read_word);
      printf ("[%d]\t\t-> 0x%08X\n", i, write_word);
  }

  /*
  if (!fail) {
    printf ("All Passed!\n");
  }
  */

}
