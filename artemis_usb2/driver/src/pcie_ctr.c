
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
#include <linux/ioport.h>

#include "nysa_pcie.h"
#include "pcie_ctr.h"


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
// SYSFS Interface
//-----------------------------------------------------------------------------

static ssize_t test_nysa_show (struct device *dev, struct device_attribute *attr, char *buf)
{
  struct pci_dev *pdev = NULL;
  nysa_pcie_dev_t * d = NULL;

  pdev = dev_get_drvdata(dev);
  d = pci_get_drvdata(pdev);

	return snprintf(buf, PAGE_SIZE, "%d\n", d->test);
}
static ssize_t test_nysa_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count)
{
  int retval = 0;
  struct pci_dev *pdev = NULL;
  nysa_pcie_dev_t * d = NULL;

  pdev = dev_get_drvdata(dev);
  d = pci_get_drvdata(pdev);
	if (sscanf(buf, "%d", &d->test) == 1)
  {
    retval = strlen(buf);
  }

  return retval;
}

static ssize_t config_space_nysa_show(struct device *dev, struct device_attribute *addr, char *buf)
{
  struct pci_dev *pdev = NULL;
  nysa_pcie_dev_t * d = NULL;

  pdev = dev_get_drvdata(dev);
  d = pci_get_drvdata(pdev);

	return snprintf(buf, PAGE_SIZE, "0x%08X\n0x%08X\n0x%08X\n0x%08X\n",
                    d->config_space[0],
                    d->config_space[1],
                    d->config_space[2],
                    d->config_space[3]);

}

static DEVICE_ATTR_RW(test_nysa);
static DEVICE_ATTR_RO(config_space_nysa);

static struct attribute * nysa_pcie_attrs [] =
{
 &dev_attr_test_nysa.attr,
 &dev_attr_config_space_nysa.attr,
 NULL,
};

ATTRIBUTE_GROUPS(nysa_pcie);

//-----------------------------------------------------------------------------
// Utility Functions
//-----------------------------------------------------------------------------
int construct_pcie_ctr(int dev_count)
{
  int i = 0;
  int retval = 0;
  nysa_pcie_devs = NULL;
  nysa_pcie_dev_count = 0;
  mod_info_dbg("Create PCIE Control\n");

  pci_class = class_create(THIS_MODULE, MODULE_NAME);
  if (IS_ERR(pci_class))
  {
    mod_info_dbg("Failed to generate a sysfs class\n");
    goto req_class_fail;
  }

  //Because we call 'kzalloc' everything should be zeroed out
  nysa_pcie_devs = (nysa_pcie_dev_t *)kzalloc(
                              MAX_DEVICES * sizeof(nysa_pcie_dev_t),
                              GFP_KERNEL);
  if (nysa_pcie_devs == NULL)
  {
    retval= -ENOMEM;
    mod_info_dbg("Failed to allocate space for the PCIE Devices\n");
    goto req_array_alloc_fail;
  }
  nysa_pcie_dev_count = dev_count;
  mod_info_dbg("Creating space for %d devices\n", nysa_pcie_dev_count);
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
  nysa_pcie_dev_t * dev;
  if (nysa_pcie_devs)
  {
    //Free Every Device, if need be

    for (i = 0; i < nysa_pcie_dev_count; i++)
    {
      dev = &nysa_pcie_devs[i];
      if (dev->pdev != NULL)
      {
        mod_info_dbg("Removing Device: %d\n", i);
        destroy_pcie_device(dev->pdev);
      }
    }
    kfree(nysa_pcie_devs);
  }

  if (pci_class)
  {
    mod_info_dbg("Destroy PCI Class\n");
    class_destroy(pci_class);
  }


  mod_info_dbg("Destroyed PCIE Controller\n");
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

int write_register(nysa_pcie_dev_t *dev, unsigned int address, unsigned int value)
{
  int retval = 0;
  mod_info_dbg("Writting Register: Addr: 0x%08X Data: 0x%08X\n", (unsigned int) address, (unsigned int) value);
  mod_info_dbg("\tVirtual Address: 0x%08zX\n", (ssize_t) (dev->virt_addr + (address << 2)));
  iowrite32(cpu_to_be32(value), (void *) (dev->virt_addr + (address << 2)));
  return retval;
}

int write_command(nysa_pcie_dev_t *dev, unsigned int address, unsigned int device_address, unsigned int value)
{
  int retval = 0;
  mod_info_dbg("Writting Command: Addr: 0x%08X Data: 0x%08X\n Device Addrss: 0x%08X\n", address, value, device_address);
  mod_info_dbg("\tVirtual Address: 0x%08zX\n", (ssize_t) (dev->virt_addr + (address << 2)));
  //iowrite32(cpu_to_be32(device_address), (void *) dev->bar_addr + HDR_DEV_ADDR);
  iowrite32(cpu_to_be32(value), (void *) (dev->virt_addr + (HDR_DEV_ADDR << 2)));
  iowrite32(cpu_to_be32(value), (void *) (dev->virt_addr + (address << 2)));
  return retval;
}

//-----------------------------------------------------------------------------
// PCIE Functionality
//-----------------------------------------------------------------------------

//MSI ISRs
irqreturn_t msi_isr(int irq, void *data)
{
  int i = 0;
  struct pci_dev * pdev;
  nysa_pcie_dev_t *dev;

  mod_info_dbg("Entered Interrupt: ISR #: %d\n", irq);
  pdev = (struct pci_dev *) data;
  dev = pci_get_drvdata(pdev);
  dma_sync_single_for_cpu(&pdev->dev, dev->status_dma_addr, NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
  memcpy(dev->config_space, dev->status_buffer, (CONFIG_REGISTER_COUNT * 4));
  dma_sync_single_for_device(&pdev->dev, dev->status_dma_addr, NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);

  /*
  mod_info_dbg("Configuration Data\n");
  for (i = 0; i < CONFIG_REGISTER_COUNT; i++)
  {
    dev->config_space[i] = be32_to_cpu(dev->config_space[i]);
    mod_info("0x%08X\n", dev->config_space[i]);
  }
  */

  switch (irq)
  {
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

	mod_info_dbg("Entered\n");

  //dev_t devno = MKDEV(major_num, index);
  major_num = MAJOR(devno);
  index = MINOR(devno);

	mod_info_dbg("Get Device at index: %d (Major: %d Minor: %d)\n", index, major_num, index);
  //Get reference to nysa_pcie_dev
  dev = &nysa_pcie_devs[index];
  mod_info_dbg("Got Device\n");


  //----------------------------
  // Configure PCIE
  //----------------------------

  mod_info_dbg("Enable PCIE Device\n");
  if ((retval = pci_enable_device(pdev)) != 0)
  {
    mod_info_dbg("Couldn't enable device\n");
    goto device_construct_fail;
  }

  mod_info_dbg("Allow PCIE Device to be a master\n");
  //Allow PCIE device to behave as a master
  pci_set_master(pdev);

  //Request Memory Region
  //Set PCIE Device to be in 32-bit mode
  mod_info_dbg("Set DMA Mask to 32 bits\n");
  if ((retval = pci_set_dma_mask(pdev, DMA_BIT_MASK(32))))
  {
    dev_err(&pdev->dev, "No suitable DMA Available\n");
    goto disable_device;
  }

  //Set Max sample size
  mod_info_dbg("Set Max Packet Size\n");
  pcie_set_mps(pdev, NYSA_MAX_PACKET_SIZE);

  //Instantiate nysa_pcie per device configuration
  dev->buffer_size = NYSA_PCIE_BUFFER_SIZE;
  dev->index = index;
  mod_info_dbg("Get the start of the base address register\n");
  dev->bar_addr = pci_resource_start(pdev, CONTROL_BAR);
  mod_info_dbg("Get the Length of the Base Address Register\n");
  dev->bar_len = pci_resource_len(pdev, CONTROL_BAR);
	mod_info_dbg("Get Base Address\n");
  if (0 > dev->bar_addr)
  {
    mod_info_dbg("Base Address was not set\n");
    goto fail_status_buffer;
  }
  mod_info_dbg("BAR Address: 0x%0zX\n", (ssize_t) dev->bar_addr);
  mod_info_dbg("BAR Length: 0x%0zX\n", (ssize_t) dev->bar_len);
	mod_info_dbg("Get Virtual Address\n");
  dev->virt_addr = ioremap(dev->bar_addr, dev->bar_len);
  if (!dev->virt_addr)
    goto fail_status_buffer;
  mod_info_dbg("Virtual Address: 0x%0zX\n", (ssize_t) dev->virt_addr);

	mod_info_dbg("Request Memory Region\n");
  if (request_mem_region(dev->bar_addr, dev->bar_len, MODULE_NAME) == NULL)
  {
    mod_info_dbg("Failed to recevie requested memory from kernel, memory already in use\n");
    retval = -1;
    goto fail_status_buffer;
  }
	mod_info_dbg("Enable MSI Interrupts\n");
  //Enable MSI Interrupt Mode
  if ((retval = pci_enable_msi(pdev)) != 0)
  {
    mod_info_dbg("Failed to enable MSI interrupt\n");
    goto fail_status_buffer;
  }
  if ((retval = request_irq(pdev->irq, msi_isr, IRQF_SHARED, MODULE_NAME, pdev)) != 0)
  {
    mod_info_dbg("Failed to get an interrupt\n");
    goto fail_status_buffer;
  }


	mod_info_dbg("Create the buffers for DMA\n");
  //Create the Buffers for DMA
  dev->status_buffer = kmalloc(NYSA_PCIE_BUFFER_SIZE, GFP_KERNEL);
  if (dev->status_buffer == NULL)
  {
    mod_info_dbg("Unable to allocate status buffer.\n");
    retval = -ENOMEM;
    goto fail_status_buffer;
  }
  //Create the DMA Mapping
  dev->status_dma_addr = pci_map_single(pdev, dev->status_buffer, NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);
  write_register(dev, HDR_STATUS_BUF_ADDR, (u32) dev->status_dma_addr);
  if (0 == dev->status_dma_addr)
  {
    mod_info_dbg("Failed to map status buffer.\n");
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
    dev->write_dma_addr[i] = pci_map_single(pdev, &dev->write_buffer[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_TODEVICE);
    if (0 == dev->write_dma_addr[i])
    {
      fail_index = i;
      goto fail_write_dma_map;
    }
  }
  write_register(dev, HDR_WRITE_BUF_A_ADDR, (u32) dev->write_dma_addr[0]);
  write_register(dev, HDR_WRITE_BUF_B_ADDR, (u32) dev->write_dma_addr[1]);

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
    dev->read_dma_addr[i] = pci_map_single(pdev, &dev->read_buffer[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_TODEVICE);
    if (0 == dev->read_dma_addr[i])
    {
      fail_index = i;
      goto fail_read_dma_map;
    }
  }

  write_register(dev, HDR_READ_BUF_A_ADDR,  (u32) dev->read_dma_addr[0]);
  write_register(dev, HDR_READ_BUF_B_ADDR,  (u32) dev->read_dma_addr[1]);
  write_register(dev, HDR_BUFFER_SIZE,      (u32) NYSA_PCIE_BUFFER_SIZE);

  mutex_init(&dev->mutex);
/*
  device = device_create( pci_class,
                          NULL,          // no parent device
                          devno,
                          pdev,          // no additional data
                          MODULE_NAME "%d",
                          index);
*/
  device = device_create_with_groups (pci_class,          // Parent Class
                                      NULL,               // No Parent Device
                                      devno,              // Major/Minor Number
                                      pdev,               // Our Data
                                      //&attr_group,      // Attribute Group
                                      nysa_pcie_groups,   // Attribute Group
                                      MODULE_NAME "%d", index);  // Format


  if (IS_ERR(device))
  {
    retval = PTR_ERR(device);
    mod_info_dbg("Error %d while trying to create %s%d\n", retval, MODULE_NAME, index);
    goto fail_reset_device;
  }
  init_completion(&dev->complete);
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
    pci_unmap_single(pdev, dev->write_dma_addr[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_TODEVICE);
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
    mod_info_dbg("Device is not initialized, do not clean up\n");
    return;
  }

  index = dev->index;
  mod_info_dbg("Destroy device: %d\n", index);

  device_destroy(pci_class, MKDEV(major_num, index));
  mutex_destroy(&dev->mutex);
  mod_info_dbg("Device: %d Clean up DMA\n", index);
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
    pci_unmap_single(pdev, dev->write_dma_addr[i], NYSA_PCIE_BUFFER_SIZE, PCI_DMA_TODEVICE);
    dev->write_dma_addr[i] = 0;
  }
  for (i = 0; i < WRITE_BUFFER_COUNT; i++)
  {
    kfree(dev->write_buffer[i]);
    dev->write_buffer[i] = NULL;
  }

  pci_unmap_single(pdev, dev->status_dma_addr, NYSA_PCIE_BUFFER_SIZE, PCI_DMA_FROMDEVICE);

  //Cleanup PCIE
  mod_info_dbg("Device: %d Clean up PCI\n", index);
  free_irq(pdev->irq, pdev);
  pci_disable_msi(pdev);

  //Disable map to virtual memory space
  iounmap(dev->virt_addr);
  release_mem_region(dev->bar_addr, dev->bar_len);

  pci_disable_device(pdev);

  dev->status_dma_addr = 0;
  kfree(dev->status_buffer);
  dev->status_buffer = NULL;
  dev->pdev = NULL;
  dev->initialized = false;
  mod_info_dbg("Device: %d destroyed\n", index);
  return;
}


