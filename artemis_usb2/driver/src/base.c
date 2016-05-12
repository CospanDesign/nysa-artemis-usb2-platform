/*
 * nysa_pcie
 *
 * Copyright (c) 2016 <your company name>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

/* This code has is influenced heavily from the following sources:
 *  Adrian Byszuk
 *  URL: https://github.com/abyszuk/fpga_pcie_driver
 *
 *  Eugene ?? http://stackoverflow.com/users/689077/eugene
 *  URL: https://github.com/euspectre/kedr/blob/master/sources/examples/sample_target/cfake.c
 *  URL: https://github.com/euspectre/kedr/blob/master/sources/examples/sample_target/cfake.h
 */

#include <linux/types.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/kernel.h>
#include <linux/errno.h>
#include <linux/fs.h>
#include <linux/sysfs.h>
#include <linux/cdev.h>
#include <asm/uaccess.h>   /* copy_to_user */


#include "nysa_pcie.h"
#include "pcie_ctr.h"

MODULE_LICENSE("GPL v2");
MODULE_AUTHOR("Dave McCoy (dave.mccoy@cospandesign.com)");
MODULE_DESCRIPTION("Nysa PCIE Interface");

//-----------------------------------------------------------------------------
// Parameters
//-----------------------------------------------------------------------------

DEFINE_PCI_DEVICE_TABLE(nysa_pcie_ids) = {
  { PCI_DEVICE(PCI_VENDOR_XILINX, PCI_DEVICE_XILINX_PCIE_RAM) },  // PCI-E Xilinx RAM Device
  {0,0,0,0},
};

static dev_t pci_driver_chrdev_num;
static int major_num;
static atomic_t device_count;

struct cdev cdevs[MAX_DEVICES];

//-----------------------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------------------
static int nysa_pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id);
static void nysa_pcie_remove(struct pci_dev *pdev);


//-----------------------------------------------------------------------------
// PCIE Specific defines
//-----------------------------------------------------------------------------

MODULE_DEVICE_TABLE(pci, nysa_pcie_ids);

//PCIE Spcecific Structure
static struct pci_driver pcidriver = {
  .name     = MODULE_NAME,
  .id_table = nysa_pcie_ids,
  .probe    = nysa_pcie_probe,
  .remove   = nysa_pcie_remove,
};

//-----------------------------------------------------------------------------
// File Operations
//-----------------------------------------------------------------------------

int nysa_pcie_open(struct inode *inode, struct file *filp)
{
  filp->private_data = get_nysa_pcie_dev(iminor(inode));
  mod_info_dbg("Opened!\n");
  mod_info_dbg("Minor Number: %d\n", iminor(inode));
  return SUCCESS;
}

int nysa_pcie_release(struct inode *inode, struct file *filp)
{
  nysa_pcie_dev_t *dev;
  dev = filp->private_data;
  return SUCCESS;
}

ssize_t nysa_pcie_write(struct file *filp, const char *buf, size_t count, loff_t *f_pos)
{
  int retval = SUCCESS;
  u32 value;
  u32 address;
  u32 device_address;
  nysa_pcie_dev_t *dev;
  u8 kernel_buf[12];

  dev = filp->private_data;

  if (is_command_mode_enabled(dev))
  {
    mod_info_dbg("Command Mode!\n");
    if (count > 12){
      mod_info_dbg("Copy only the first 12-bytes\n");
      copy_from_user(kernel_buf, buf, 12);
    }
    else
      copy_from_user(kernel_buf, buf, count);

    address         = (kernel_buf[0] << 24) | (kernel_buf[1] << 16) | (kernel_buf[2]  << 8) | (kernel_buf[3]);
    value           = (kernel_buf[4] << 24) | (kernel_buf[5] << 16) | (kernel_buf[6]  << 8) | (kernel_buf[7]);
    device_address  = (kernel_buf[8] << 24) | (kernel_buf[9] << 16) | (kernel_buf[10] << 8) | (kernel_buf[11]);

    mod_info_dbg("Write: 0x%08X 0x%08X 0x%08X\n", (unsigned int) address, (unsigned int)value, (unsigned int)device_address);

    //Need to determine if this is a register write or a command, if it is a command see if it takes an address
    if (address < CMD_OFFSET)
    {
      //Write a Register
      write_register(dev, address, value);
    }
    else
    {
      //Write Command
      mod_info_dbg("Not Command Mode!\n");
      write_command(dev, address, device_address, value);
    }
  }
  else
  {
    mod_info_dbg("Write Data: Count: 0x%08X\n", (unsigned int) count);
    //return retval;
    return nysa_pcie_write_data(dev, buf, count);
  }
  //Check to see if this is a command or just a register
  return retval;
}

ssize_t nysa_pcie_read(struct file *filp, char __user * buf, size_t count, loff_t *f_pos)
{

  nysa_pcie_dev_t *dev;
  dev = filp->private_data;
  mod_info_dbg("Buffer Pointer: %p\n", buf);
  return nysa_pcie_read_data(dev, buf, count);
}

loff_t nysa_pcie_llseek (struct file * filp, loff_t off, int whence)
{
  nysa_pcie_dev_t *dev;

  dev = filp->private_data;
  enable_command_mode(dev, false);

  mod_info_dbg("in llseek\n");
  switch (whence)
  {
    case 0: //Set
      mod_info_dbg("disable command mode!\n");
      break;
    case 1: //Current Position
      mod_info_dbg("disable command mode!\n");
      break;
    case 2: //End
      mod_info_dbg("enable command mode!\n");
      enable_command_mode(dev, true);
      break;
    default:
      return -EINVAL;
  }

  return 0;
}

struct file_operations nysa_pcie_fops = {
  owner:    THIS_MODULE,
  read:     nysa_pcie_read,
  write:    nysa_pcie_write,
  open:     nysa_pcie_open,
  release:  nysa_pcie_release,
  llseek:   nysa_pcie_llseek
};

//-----------------------------------------------------------------------------
// Device Detect/Remove
//-----------------------------------------------------------------------------
static int nysa_pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id)
{
  int retval = 0;
  int minor = 0;
  dev_t devno;
  mod_info_dbg("Found PCI Device: %04X:%04X %s\n", id->vendor, id->device, dev_name(&pdev->dev));

  //Increment the Device ID
  minor = atomic_inc_return(&device_count) - 1;
  devno = MKDEV(major_num, minor);

  if (minor >= MAX_DEVICES)
  {
    mod_info_dbg("Maximum Number of Devices Reached! Increase MAX_DEVICES.\n");
    goto probe_fail;
  }

  //----------------------------
  // Configure PCIE
  //----------------------------
  if ((retval = construct_pcie_device(pdev, devno)) != 0)
  {
    mod_info_dbg("Failed to create device.\n");
    goto probe_decrement_minor;
  }

  //----------------------------
  // Configure Character Devices
  //----------------------------
  cdev_init(&cdevs[minor], &nysa_pcie_fops);
  if ((retval = cdev_add(&cdevs[minor], devno, 1)) != 0)
  {
    mod_info_dbg("Error %d while trying to add cdev for minor: %d\n", retval, minor);
    goto probe_destroy_pcie_device;
  }
  set_nysa_pcie_private(minor, (void *) &cdevs[minor]);
  return SUCCESS;

//Handle Fails
probe_destroy_pcie_device:
  destroy_pcie_device(pdev);
probe_decrement_minor:
  atomic_dec(&device_count);
probe_fail:
  return retval;
}

static void nysa_pcie_remove(struct pci_dev *pdev)
{
  //----------------------------
  // Destroy Character Device
  //----------------------------
  nysa_pcie_dev_t *dev;
  int index = 0;
  struct cdev *cdv = NULL;
	mod_info_dbg("Entered\n");

	mod_info_dbg("Removing Character Device\n");
  dev = pci_get_drvdata(pdev);
  index = get_nysa_pcie_dev_index(dev);
  //cdv = (struct cdev *)get_nysa_pcie_private(index);
  cdv = &cdevs[index];

  //----------------------------
  // Destroy PCIE Controller
  //----------------------------

  destroy_pcie_device(pdev);
	mod_info_dbg("Deleted Character Device\n");
  cdev_del(cdv);
	mod_info_dbg("Destroyed PCIE Device\n");
  atomic_dec(&device_count);
}

//-----------------------------------------------------------------------------
// Module Init/Exit
//-----------------------------------------------------------------------------

static int __init nysa_pcie_init(void)
{
  int i = 0;
  int retval = SUCCESS;
  atomic_set(&device_count, 0);

  //Request a set of character device numbers
  mod_info_dbg("Registering Driver\n");
  if ((retval = alloc_chrdev_region(&pci_driver_chrdev_num, MINOR_NUM_START, MAX_DEVICES, MODULE_NAME)) != 0)
  {
    mod_info_dbg("Failed to create chrdev region");
    goto init_fail;
  }
  major_num = MAJOR(pci_driver_chrdev_num);

  //Create a reference to all the pci devices we will be interfacing with
  if ((retval = construct_pcie_ctr(MAX_DEVICES)) != 0)
  {
    goto unregister_chrdev_region;
  }

  //Initialize each of the possible character devices
  for (i = 0; i < MAX_DEVICES; i++)
  {
    cdevs[i].owner = THIS_MODULE;
  }

  //Register the PCI IDs with the kernel
  if ((retval = pci_register_driver(&pcidriver)) != 0)
  {
    mod_info_dbg("Failed to register PCI Driver\n");
    goto register_fail;
  }

  mod_info_dbg("Driver Initialized, waiting for probe...\n");
  return SUCCESS;

//Handle Fail

register_fail:
  destroy_pcie_ctr();
unregister_chrdev_region:
  unregister_chrdev_region(MAJOR(pci_driver_chrdev_num), MAX_DEVICES);
init_fail:
  return retval;
}

static void __exit nysa_pcie_exit(void)
{
  mod_info_dbg("Cleanup Module\n");

  //Tell the kernel we are not listenning for PCI devices
	mod_info_dbg("Unregistering Driver\n");
  pci_unregister_driver(&pcidriver);
	mod_info_dbg("Unregistering Character Driver\n");
  unregister_chrdev_region(pci_driver_chrdev_num, MAX_DEVICES);
  destroy_pcie_ctr();
  atomic_set(&device_count, 0);
	mod_info_dbg("Finished Cleanup Module, Exiting\n");
  return;
}

module_init(nysa_pcie_init);
module_exit(nysa_pcie_exit);


