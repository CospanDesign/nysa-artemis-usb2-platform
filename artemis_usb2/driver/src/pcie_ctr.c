
#include <linux/types.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include <linux/kernel.h>
#include <linux/errno.h>
#include <linux/fs.h>
#include <linux/sysfs.h>
#include <asm/uaccess.h>   /* copy_to_user */

#include "nysa_pcie.h"
#include "pcie_ctr.h"

//Keep a list of devices
static struct class * pci_class;
static nysa_pcie_dev_t *nysa_pcie_devs;
int nysa_pcie_dev_count = 0;
int major_num;

enum MSI_ISR
{
  NYSA_RESET = 0,
  NYSA_CMD_DONE,
  NYSA_CONTROL_WRITE,
  NYSA_CONTROL_READ,
  NYSA_MEM_WRITE,
  NYSA_MEM_READ,
  NYSA_DMA_WRITE,
  NYSA_DMA_READ,
  NYSA_GEN_INTERRUPT,
  NYSA_DMA_INGRESS_INTERRUPT,
  NYSA_DMA_EGRESS_INTERRUPT,
  NYSA_PACKET_DONE,
  NUM_MSI_VECS
};

//-----------------------------------------------------------------------------
// Utility Functions
//-----------------------------------------------------------------------------
int construct_pcie_ctr(int dev_count)
{
  int i = 0;
  int retval = 0;
  nysa_pcie_devs = NULL;
  nysa_pcie_dev_count = 0;
  mod_info("Create PCIE Control\n");

  pci_class = class_create(THIS_MODULE, MODULE_NAME);
  if (IS_ERR(pci_class))
  {
    mod_info("Failed to generate a sysfs class\n");
    goto req_class_fail;
  }

  //Because we call 'kzalloc' everything should be zeroed out
  nysa_pcie_devs = (nysa_pcie_dev_t *)kzalloc(
                              MAX_DEVICES * sizeof(nysa_pcie_dev_t),
                              GFP_KERNEL);
  if (nysa_pcie_devs == NULL)
  {
    retval= -ENOMEM;
    mod_info("Failed to allocate space for the PCIE Devices\n");
    goto req_array_alloc_fail;
  }
  nysa_pcie_dev_count = dev_count;
  mod_info("Creating space for %d devices\n", nysa_pcie_dev_count);
  for (i = 0; i < nysa_pcie_dev_count; i++)
  {
    nysa_pcie_devs[i].initialized = false;
  }
  //Success!
  return retval;

req_array_alloc_fail:
  class_destroy(pci_class);
req_class_fail:
  return retval;
}

void destroy_pcie_ctr(void)
{
  int i = 0;
  if (pci_class)
    class_destroy(pci_class);

  if (nysa_pcie_devs)
  {
    //Free Every Device, if need be

    for (i = 0; i < nysa_pcie_dev_count; i++)
    {
      if (nysa_pcie_devs[i].pdev != NULL)
      {
        mod_info("Removing Device: %d\n", i);
        destroy_pcie_device(nysa_pcie_devs[i].pdev);
      }
    }
    kfree(nysa_pcie_devs);
  }
  mod_info("Destroyed PCIE Controller\n");
  nysa_pcie_devs = NULL;
}

void set_nysa_pcie_private(int index, void * data)
{
  nysa_pcie_devs[index].private_data = data;
}

void * get_nysa_pcie_private(int index)
{
  return nysa_pcie_devs[index].private_data;
}

nysa_pcie_dev_t * get_nysa_pcie_dev(int index)
{
  return &nysa_pcie_devs[index];
}

int get_nysa_pcie_dev_index(nysa_pcie_dev_t * dev)
{
  return dev->index;
}

//-----------------------------------------------------------------------------
// PCIE Functionality
//-----------------------------------------------------------------------------

//MSI ISRs
irqreturn_t msi_isr(int irq, void *data)
{
//XXX: Need to figure out how to send a reference to the associated device driver

  mod_info("Entered Interrupt: ISR#: %d\n", irq);
  switch (irq){
    case NYSA_RESET:
      break;
    case NYSA_CMD_DONE:
      break;
    case NYSA_CONTROL_WRITE:
      break;
    case NYSA_CONTROL_READ:
      break;
    case NYSA_MEM_WRITE:
      break;
    case NYSA_MEM_READ:
      break;
    case NYSA_DMA_WRITE:
      break;
    case NYSA_DMA_READ:
      break;
    case NYSA_GEN_INTERRUPT:
      break;
    case NYSA_DMA_INGRESS_INTERRUPT:
      break;
    case NYSA_DMA_EGRESS_INTERRUPT:
      break;
    case NYSA_PACKET_DONE:
      break;
    default:
      break;
  }

  return IRQ_HANDLED;
}

//Device
int construct_pcie_device(struct pci_dev *pdev, dev_t devno)
{
  int index = 0;
  int retval = 0;
  int i = 0;
  int fail_index = 0;
  struct device *device = NULL;
  nysa_pcie_dev_t *dev;

  //dev_t devno = MKDEV(major_num, index);
  major_num = MAJOR(devno);
  index = MINOR(devno);

  //Get reference to nysa_pcie_dev
  dev = &nysa_pcie_devs[index];


  //----------------------------
  // Configure PCIE
  //----------------------------

  if ((retval = pci_enable_device(pdev)) != 0) {
    mod_info("Couldn't enable device\n");
    goto device_construct_fail;
  }

  //Allow PCIE device to behave as a master
  pci_set_master(pdev);

  //Request Memory Region
  //Set PCIE Device to be in 32-bit mode
  if ((retval = pci_set_consistent_dma_mask(pdev, DMA_BIT_MASK(32)))) {
    dev_err(&pdev->dev, "No suitable DMA Available");
    goto disable_device;
  }

  //Set Max sample size
  pcie_set_mps(pdev, NYSA_MAX_PACKET_SIZE);

  //Instantiate nysa_pcie per device configuration
  dev->buffer_size = NYSA_PCIE_BUFFER_SIZE;
  dev->index = index;
  dev->bar_addr = pci_resource_start(pdev, CONTROL_BAR);
  dev->bar_len = pci_resource_len(pdev, dev->bar_addr);
  if (0 > dev->bar_addr)
  {
    mod_info("Base Address was not set\n");
    goto fail_status_buffer;
  }
  dev->virt_addr = (unsigned long) ioremap(dev->bar_addr, dev->bar_len);
  if (!dev->virt_addr)
    goto fail_status_buffer;

  if (request_mem_region(dev->bar_addr, dev->bar_len, MODULE_NAME) == NULL){
    mod_info("Failed to recevie requested memory from kernel, memory already in use\n");
    retval = -1;
    goto fail_status_buffer;
  }
  //Enable MSI Interrupt Mode
  if ((retval = pci_enable_msi(pdev)) != 0)
  {
    mod_info("Failed to enable MSI interrupt");
    goto fail_status_buffer;
  }
  if ((retval = request_irq(pdev->irq, msi_isr, IRQF_SHARED, MODULE_NAME, pdev)) != 0)
  {
    mod_info("Failed to get an interrupt");
    goto fail_status_buffer;
  }


  //Create the Buffers for DMA
  dev->status_buffer = kzalloc(NYSA_PCIE_BUFFER_SIZE, GFP_KERNEL);
  if (dev->status_buffer == NULL) {
    mod_info("Unable to allocate status buffer.\n");
    retval = -ENOMEM;
    goto fail_status_buffer;
  }
  //Create the DMA Mapping
  pci_map_single(pdev, dev->status_buffer, NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
  if (0 == dev->status_dma_addr){
    mod_info("Failed to map status buffer.\n");
    retval = -1;
    goto fail_unmap_status_buffer;
  }


  //Create the buffers for read and write buffers
  //XXX: In the future this should be a scatter/gather interface
  for (i = 0; i < WRITE_BUFFER_COUNT; i++)
  {
    dev->write_buffer[i] = kzalloc(NYSA_PCIE_BUFFER_SIZE, GFP_KERNEL);
    if (dev->write_buffer[i] == NULL)
    {
      fail_index = i;
      goto fail_write_buffer;
    }
  }
  for (i = 0; i < WRITE_BUFFER_COUNT; i++)
  {
    pci_map_single(pdev, &dev->write_buffer[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_TODEVICE);
    if (0 == dev->write_dma_addr[i]){
      fail_index = i;
      goto fail_write_dma_map;
    }
  }

  for (i = 0; i < READ_BUFFER_COUNT; i++)
  {
    dev->read_buffer[i] = kzalloc(NYSA_PCIE_BUFFER_SIZE, GFP_KERNEL);
    if (dev->read_buffer[i] == NULL)
    {
      fail_index = i;
      goto fail_read_buffer;
    }
  }
  for (i = 0; i < READ_BUFFER_COUNT; i++)
  {
    pci_map_single(pdev, &dev->read_dma_addr[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_TODEVICE);
    if (0 == dev->read_dma_addr[i]){
      fail_index = i;
      goto fail_read_dma_map;
    }
  }


  mutex_init(&dev->mutex);
  device = device_create( pci_class, NULL,          /* no parent device */
                          devno, NULL,              /* no additional data */
                          MODULE_NAME "%d", index);

  if (IS_ERR(device)) {
    retval = PTR_ERR(device);
    mod_info(KERN_WARNING "[target] Error %d while trying to create %s%d\n", retval, MODULE_NAME, index);
    goto fail_reset_device;
  }
  dev->pdev = pdev;

  pci_set_drvdata(pdev, dev);
  dev->initialized = true;
  return SUCCESS;

//Handle Failures
fail_reset_device:
  mutex_destroy(&dev->mutex);
  fail_index = READ_BUFFER_COUNT;
fail_read_dma_map:
  for (i = 0; i < fail_index; i++)
  {
    pci_unmap_single(pdev, dev->read_dma_addr[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
    dev->read_dma_addr[i] = 0;
  }
  fail_index = READ_BUFFER_COUNT;
fail_read_buffer:
  for (i = 0; i < fail_index; i++)
  {
    kfree(dev->read_buffer[i]);
    dev->read_buffer[i] = NULL;
  }
  fail_index = WRITE_BUFFER_COUNT;
fail_write_dma_map:
  for (i = 0; i < fail_index; i++)
  {
    pci_unmap_single(pdev, dev->write_dma_addr[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
    dev->write_dma_addr[i] = 0;
  }
  fail_index = WRITE_BUFFER_COUNT;
fail_write_buffer:
  for (i = 0; i < fail_index; i++)
  {
    kfree(dev->write_buffer[i]);
    dev->write_buffer[i] = NULL;
  }

//fail_status_buffer:
  pci_unmap_single(pdev, dev->status_dma_addr, NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
  dev->status_dma_addr = 0;
fail_unmap_status_buffer:
  kfree(dev->status_buffer);
  dev->status_buffer = NULL;

fail_status_buffer:
  release_mem_region(dev->bar_addr, dev->bar_len);
  dev->pdev = NULL;

disable_device:
  pci_disable_device(pdev);

device_construct_fail:

  return retval;

}

void destroy_pcie_device(struct pci_dev *pdev)
{
  int i = 0;
  int index = 0;
  nysa_pcie_dev_t *dev = NULL;
  dev = pci_get_drvdata(pdev);
  if (!dev->initialized)
  {
    //Nothing to do, we are not initialized
    return;
  }

  pdev = dev->pdev;
  index = dev->index;
  mod_info("Destroy device: %d", index);

  device_destroy(pci_class, MKDEV(major_num, index));
  mutex_destroy(&dev->mutex);
  for (i = 0; i < READ_BUFFER_COUNT; i++)
  {
    pci_unmap_single(pdev, dev->read_dma_addr[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
    dev->read_dma_addr[i] = 0;
  }
  for (i = 0; i < READ_BUFFER_COUNT; i++)
  {
    kfree(dev->read_buffer[i]);
    dev->read_buffer[i] = NULL;
  }
  for (i = 0; i < WRITE_BUFFER_COUNT; i++)
  {
    pci_unmap_single(pdev, dev->write_dma_addr[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
    dev->write_dma_addr[i] = 0;
  }
  for (i = 0; i < WRITE_BUFFER_COUNT; i++)
  {
    kfree(dev->write_buffer[i]);
    dev->write_buffer[i] = NULL;
  }

  release_mem_region(dev->bar_addr, dev->bar_len);
  pci_unmap_single(pdev, dev->status_dma_addr, NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
  dev->status_dma_addr = 0;
  kfree(dev->status_buffer);
  dev->status_buffer = NULL;
  dev->pdev = NULL;
  dev->initialized = false;
  return;
}



