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
//-- Filename: xpcie.c
//--
//-- Description: XPCIE device driver.
//--
//-- XPCIE is an example Red Hat device driver for the PCI Express Memory
//-- Endpoint Reference design. Device driver has been tested on fedora
//-- 2.6.18.
//--
//--
//--
//--
//--
//--------------------------------------------------------------------------------
*/

#include <linux/init.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/byteorder/generic.h>
//#include <linux/pci-ats.h>
#include <linux/ioport.h>
#include <linux/interrupt.h>
#include <linux/fs.h>
#include <linux/aer.h>
#include <asm/uaccess.h>   /* copy_to_user */

// semaphores
enum  {
        SEM_READ,
        SEM_WRITE,
        SEM_WRITEREG,
        SEM_READREG,
        SEM_WAITFOR,
        SEM_DMA,
        NUM_SEMS
};

//semaphores
struct semaphore pcie_semaphore[NUM_SEMS];

MODULE_LICENSE("Dual BSD/GPL");

// Max DMA Buffer Size

#define BUF_SIZE                  4096

#define PCI_VENDOR_ID_XILINX      0x10ee
#define PCI_DEVICE_ID_XILINX_PCIE 0x0007
#define KINBURN_REGISTER_SIZE     (4*8)    // There are eight registers, and each is 4 bytes wide.
#define HAVE_REGION               0x01     // I/O Memory region
#define HAVE_IRQ                  0x02     // Interupt
#define SUCCESS                   0
#define CRIT_ERR                  -1

#define CONTROL_BAR               0
#define MEMORY_BAR                1

//Status Flags:
//       1 = Resouce successfully acquired
//       0 = Resource not acquired.
#define HAVE_REGION 0x01                    // I/O Memory region
#define HAVE_IRQ    0x02                    // Interupt
#define HAVE_KREG   0x04                    // Kernel registration

int             MAJOR             = 240;    // Major number not dynamic.
unsigned int    STAT_FLAGS        = 0x00;   // Status flags used for cleanup.
unsigned long   BAR_LEN;                    // Base register address Length
unsigned long   BAR_HDWR_ADDR;              // Base register address (Hardware address)
void           *BAR_VIRT_ADDR     = NULL;   // Base register address (Virtual address, for I/O).
char            DRIVER_NAME[]     = "xpcie";// Name of driver in proc.
struct pci_dev *DEVICE            = NULL;   // PCI device structure.
int             IRQ;                        // IRQ assigned by PCI system.
char           *BUFFER_UNALIGNED  = NULL;   // Pointer to Unaligned DMA buffer.
char           *READ_BUFFER       = NULL;   // Pointer to dword aligned DMA buffer.
char           *WRITE_BUFFER      = NULL;   // Pointer to dword aligned DMA buffer.

ssize_t xpcie_write_mem(const char *buf, size_t count);
ssize_t xpcie_read_mem(char *buf, size_t count);

//-----------------------------------------------------------------------------
// File Operations
//-----------------------------------------------------------------------------

/*****************************************************************************
 * Name:        xpcie_open
 *
 * Description: Book keeping routine invoked each time the device is opened.
 *
 * Arguments: inode :
 *            filp  :
 *
 * Returns: 0 on success, error code on failure.
 *
 * Modification log:
 * Date      Who  Description
 * --------  ---  ----------------------------------------------------------
 *
 ****************************************************************************/
int xpcie_open(struct inode *inode, struct file *filp)
{
    //MOD_INC_USE_COUNT;
    printk("%s: Open: module opened\n",DRIVER_NAME);
    return SUCCESS;
}

/*****************************************************************************
 * Name:        xpcie_release
 *
 * Description: Book keeping routine invoked each time the device is closed.
 *
 * Arguments: inode :
 *            filp  :
 *
 * Returns: 0 on success, error code on failure.
 *
 * Modification log:
 * Date      Who  Description
 * --------  ---  ----------------------------------------------------------
 *
 ****************************************************************************/
int xpcie_release(struct inode *inode, struct file *filp)
{
    //MOD_DEC_USE_COUNT;
    printk("%s: Release: module released\n",DRIVER_NAME);
    return(SUCCESS);
}

/***************************************************************************
 * Name:        xpcie_write
 *
 * Description: This routine is invoked from user space to write data to
 *              the 3GIO device.
 *
 * Arguments: filp  : file pointer to opened device.
 *            buf   : pointer to location in users space, where data is to
 *                    be acquired.
 *            count : Amount of data in bytes user wishes to send.
 *
 * Returns: SUCCESS  = Success
 *          CRIT_ERR = Critical failure
 *          TIME_ERR = Timeout
 *          LINK_ERR = Link Failure
 *
 * Modification log:
 * Date      Who  Description
 * --------  ---  ----------------------------------------------------------
 *
 ****************************************************************************/
ssize_t xpcie_write(struct file *filp, const char *buf, size_t count,
                       loff_t *f_pos){
	int ret = SUCCESS;
  u32 value;
  u8 kernel_buf[512];
  u32 addr = 0;
  copy_from_user(kernel_buf, buf, count);

  value = (kernel_buf[0] << 24) | (kernel_buf[1] << 16) | (kernel_buf[2] << 8) | (kernel_buf[3]);
  //value = (buf[0] << 24) + (buf[1] << 16) + (buf[2] << 8) + (buf[3]);
	printk("%s: xpcie_write: Attempt to write 0x%08X to %zX with offset %zX...\n", DRIVER_NAME, value, (size_t) BAR_VIRT_ADDR, (size_t) *f_pos);

	//memcpy(BAR_VIRT_ADDR, &buf[0], count);
	//memcpy(BAR_VIRT_ADDR, &kernel_buf[0], count);
	//memcpy(BAR_VIRT_ADDR, &buf[0], count);

  //Data is written down a byte at a time
  //memcpy(BAR_VIRT_ADDR, kernel_buf, count);

  //*** When I use this the data is written down in the correct order!
	//memcpy(BAR_VIRT_ADDR, &buf[0], 4);

  //**** When I use this the data is written down in reverse order
  //iowrite32(value, BAR_VIRT_ADDR + addr);
  writel(cpu_to_be32(value), BAR_VIRT_ADDR + addr);

  //xpcie_write_mem(buf, count);

	printk("%s: xpcie_write: %zu bytes have been written to %zX...\n", DRIVER_NAME, count, (size_t) BAR_VIRT_ADDR);
	return (ret);
}

/***************************************************************************
 * Name:        xpcie_read
 *
 * Description: This routine is invoked from user space to read data from
 *              the 3GIO device. ***NOTE: This routine returns the entire
 *              buffer, (BUF_SIZE), count is ignored!. The user App must
 *              do any needed processing on the buffer.
 *
 * Arguments: filp  : file pointer to opened device.
 *            buf   : pointer to location in users space, where data is to
 *                    be placed.
 *            count : Amount of data in bytes user wishes to read.
 *
 * Returns: SUCCESS  = Success
 *          CRIT_ERR = Critical failure
 *          TIME_ERR = Timeout
 *          LINK_ERR = Link Failure
 *
 *
 * Modification log:
 * Date      Who  Description
 * --------  ---  ----------------------------------------------------------
 *
 ****************************************************************************/
ssize_t xpcie_read(struct file *filp, char *buf, size_t count, loff_t *f_pos)
{
  unsigned int i = 0;
  for (i = 0; i < count + 3; i = i + 4){
	  memcpy(&buf[i], (BAR_VIRT_ADDR + i), 4);
  }
	printk("%s: xpcie_read: %zu bytes have been read from %zX ...\n", DRIVER_NAME, count, (size_t) BAR_VIRT_ADDR);
	return (0);
}

struct file_operations xpcie_intf = {
    read:       xpcie_read,
    write:      xpcie_write,
    open:       xpcie_open,
    release:    xpcie_release,
};

//-----------------------------------------------------------------------------
// Prototypes
//-----------------------------------------------------------------------------
void    xpcie_irq_handler (int irq, void *dev_id, struct pt_regs *regs);
void    initcode(void);
u32     xpcie_read_reg (u32 dw_offset);
void    xpcie_write_reg (u32 dw_offset, u32 val);

static int xpcie_init(void)
{

    int result = 0;
    int i = 0;
    //Initialize Semaphors
    for (i = 0; i < NUM_SEMS; i++){
      sema_init(&pcie_semaphore[i], 1);
    }
    //Configure the Kernel Side
    DEVICE = pci_get_device (PCI_VENDOR_ID_XILINX, PCI_DEVICE_ID_XILINX_PCIE, DEVICE);
    if (NULL == DEVICE) {
        printk("%s: Init: Hardware not found.\n", DRIVER_NAME);
        return -1;
    }
    if (0 > pci_enable_device(DEVICE)) {
        printk("%s: Init: Device not enabled.\n", DRIVER_NAME);
        return -1;
    }
    pci_enable_pcie_error_reporting(DEVICE);
    if (0 > pci_set_dma_mask(DEVICE, DMA_BIT_MASK(32))){
        printk("%s: Init: Failed to set DMA Mask.\n", DRIVER_NAME);
        return (-1);
    }

    //Get the start address of the control bar within io memory
    BAR_HDWR_ADDR = pci_resource_start (DEVICE, CONTROL_BAR);
    if (0 > BAR_HDWR_ADDR) {
        printk("%s: Init: Base Address not set.\n", DRIVER_NAME);
        return (-1);
    }
    printk("%s: Base hw val %X\n", DRIVER_NAME, (unsigned int)BAR_HDWR_ADDR);
    //Get the length of the control bar
    BAR_LEN = pci_resource_len (DEVICE, CONTROL_BAR);
    printk("%s: Base hw len %d\n", DRIVER_NAME, (unsigned int)BAR_LEN);

    //Tell the processor translator to give us a reference to BAR in an accessable location
    //  (within virtual memory)
    BAR_VIRT_ADDR = ioremap(BAR_HDWR_ADDR, BAR_LEN);
    if (!BAR_VIRT_ADDR) {
        printk("%s: Init: Could not remap memory.\n", DRIVER_NAME);
        return (-1);
    }
    printk("%s: Virt hw val %zX\n", DRIVER_NAME, (size_t)BAR_VIRT_ADDR);

    // Get IRQ from pci_dev structure. It may have been remapped by the kernel,
    // and this value will be the correct one.
    IRQ = DEVICE->irq;
    printk("%s: irq: %d\n", DRIVER_NAME, IRQ);

    //Allow the PCIE device to initiate transfers
    pci_set_master(DEVICE);
    //Increase the sampling size of the device to 512 (Max)
    pcie_set_mps(DEVICE, 512);

    //Tell the kernel that we want to have access to this memory region (it does not allocate space!)
    if (request_mem_region(BAR_HDWR_ADDR, BAR_LEN, DRIVER_NAME) == NULL) {
        printk("%s: Init: Memory in use.\n", DRIVER_NAME);
        return (-1);
    }
    STAT_FLAGS = STAT_FLAGS | HAVE_REGION;
    printk("%s: Init:  Initialize Hardware Done..\n",DRIVER_NAME);

    // Request IRQ from OS.
#if 0
    if (0 > request_irq(IRQ, &xpcie_irq_handler,/* SA_INTERRUPT |*/ SA_SHIRQ, DRIVER_NAME, DEVICE)) {
        printk(/*KERN_WARNING*/"%s: Init: Unable to allocate IRQ",DRIVER_NAME);
        return (-1);
    }
    STAT_FLAGS = STAT_FLAGS | HAVE_IRQ;
#endif

    initcode();
    BUFFER_UNALIGNED = kmalloc(BUF_SIZE, GFP_KERNEL);

    READ_BUFFER = BUFFER_UNALIGNED;
    if (NULL == BUFFER_UNALIGNED) {
        printk("%s: Init: Unable to allocate gBuffer.\n",DRIVER_NAME);
        return (-1);
    }

    WRITE_BUFFER = kmalloc(BUF_SIZE, GFP_KERNEL);
    if (NULL == WRITE_BUFFER) {
        printk("%s: Init: Unable to allocate gBuffer.\n",DRIVER_NAME);
        return (-1);
    }

    //--- END: Allocate Buffers

    //--- START: Register Driver
    // Register with the kernel as a character device.
    // Abort if it fails.
    if (0 > register_chrdev(MAJOR, DRIVER_NAME, &xpcie_intf)) {
        printk("%s: Init: will not register\n", DRIVER_NAME);
        return (CRIT_ERR);
    }
    printk("%s: Init: module registered\n", DRIVER_NAME);
    STAT_FLAGS = STAT_FLAGS | HAVE_KREG;

    printk("%s driver is loaded\n", DRIVER_NAME);

  return result;
}

static void xpcie_exit(void)
{

  //pci_release_regions(DEVICE);
  if (STAT_FLAGS & HAVE_REGION) {
     (void) release_mem_region(BAR_HDWR_ADDR, BAR_LEN);}

    // Release IRQ
    if (STAT_FLAGS & HAVE_IRQ) {
        (void) free_irq(IRQ, DEVICE);
    }


    // Free buffer
    if (NULL != READ_BUFFER)
        (void) kfree(READ_BUFFER);
    if (NULL != WRITE_BUFFER)
        (void) kfree(WRITE_BUFFER);

    READ_BUFFER = NULL;
    WRITE_BUFFER = NULL;


    if (BAR_VIRT_ADDR != NULL) {
        iounmap(BAR_VIRT_ADDR);
     }

    BAR_VIRT_ADDR = NULL;


    // Unregister Device Driver
    if (STAT_FLAGS & HAVE_KREG) {
	unregister_chrdev(MAJOR, DRIVER_NAME);
//        if (unregister_chrdev(MAJOR, DRIVER_NAME) > 0) {
//            printk(KERN_WARNING"%s: Cleanup: unregister_chrdev failed\n",
//                   DRIVER_NAME);
//        }
    }

    STAT_FLAGS = 0;

  printk("%s driver is unloaded\n", DRIVER_NAME);
}

module_init(xpcie_init);
module_exit(xpcie_exit);

//-----------------------------------------------------------------------------
// Internal Functions
//-----------------------------------------------------------------------------

void xpcie_irq_handler(int irq, void *dev_id, struct pt_regs *regs)
{
}

void initcode(void)
{
}

u32 xpcie_read_reg (u32 dw_offset)
{
        size_t ret = 0;
        size_t reg_addr = (size_t)(BAR_VIRT_ADDR + dw_offset);

        ret = readb((void*)reg_addr);

        return ret;
}

void xpcie_write_reg (u32 dw_offset, u32 val)
{
        size_t reg_addr = (size_t)(BAR_VIRT_ADDR + dw_offset);
        writel(cpu_to_be32(val), (void*)reg_addr);
}

ssize_t xpcie_read_mem(char *buf, size_t count)
{

    int ret = 0;
    dma_addr_t dma_addr;

    //make sure passed in buffer is large enough
    if ( count < BUF_SIZE )  {
      printk("%s: xpcie_read: passed in buffer too small.\n", DRIVER_NAME);
      ret = -1;
      goto exit;
    }

    down(&pcie_semaphore[SEM_DMA]);

    // pci_map_single return the physical address corresponding to
    // the virtual address passed to it as the 2nd parameter

    dma_addr = pci_map_single(DEVICE, READ_BUFFER, BUF_SIZE, PCI_DMA_FROMDEVICE);
    if ( 0 == dma_addr )  {
        printk("%s: xpcie_read: Map error.\n",DRIVER_NAME);
        ret = -1;
        goto exit;
    }

    // Now pass the physical address to the device hardware. This is now
    // the destination physical address for the DMA and hence the to be
    // put on Memory Transactions

    // Do DMA transfer here....

    printk("%s: xpcie_read: ReadBuf Virt Addr = %zX Phy Addr = %zX.\n", DRIVER_NAME, (size_t)READ_BUFFER, (size_t)dma_addr);

    // Unmap the DMA buffer so it is safe for normal access again.
    pci_unmap_single(DEVICE, dma_addr, BUF_SIZE, PCI_DMA_FROMDEVICE);

    up(&pcie_semaphore[SEM_DMA]);

    // Now it is safe to copy the data to user space.
    if ( copy_to_user(buf, READ_BUFFER, BUF_SIZE) )  {
        ret = -1;
        printk("%s: xpcie_read: Failed copy to user.\n",DRIVER_NAME);
        goto exit;
    }
    exit:
      //return ((ssize_t*) ret);
      //return ((ssize_t*) &BUF_SIZE);
      return 0;
    return 0;
}

ssize_t xpcie_write_mem(const char *buf, size_t count)
{
    int ret = 0;
    dma_addr_t dma_addr;

    printk ("%s: xpcie_write_mem: Entered\n", DRIVER_NAME);

    if ( (count % 4) != 0 )  {
       printk("%s: xpcie_write_mem: Buffer length not dword aligned.\n",DRIVER_NAME);
       ret = -1;
       goto exit;
    }

    // Now it is safe to copy the data from user space.
    if ( copy_from_user(WRITE_BUFFER, buf, count) )  {
        ret = -1;
        printk("%s: xpcie_write_mem: Failed copy to user.\n",DRIVER_NAME);
        goto exit;
    }
    printk ("%s: xpcie_write_mem: Try and get the Semaphore\n", DRIVER_NAME);

    //set DMA semaphore if in loopback
    down(&pcie_semaphore[SEM_DMA]);

    printk ("%s: xpcie_write_mem: Got the Semaphore\n", DRIVER_NAME);

    // pci_map_single return the physical address corresponding to
    // the virtual address passed to it as the 2nd parameter
    dma_addr = pci_map_single(DEVICE, WRITE_BUFFER, BUF_SIZE, PCI_DMA_TODEVICE);
    if ( 0 == dma_addr )  {
        printk("%s: xpcie_write_mem: Map error.\n",DRIVER_NAME);
        ret = -1;
        goto exit;
    }
    printk ("%s: xpcie_write_mem: Received the address\n", DRIVER_NAME);

    // Now pass the physical address to the device hardware. This is now
    // the source physical address for the DMA and hence the to be
    // put on Memory Transactions

    // Do DMA transfer here....
    printk("%s: xpcie_write_mem: WriteBuf Virt Addr = %zX Phy Addr = %zX.\n", DRIVER_NAME, (size_t)READ_BUFFER, (size_t)dma_addr);

    // Unmap the DMA buffer so it is safe for normal access again.
    pci_unmap_single(DEVICE, dma_addr, BUF_SIZE, PCI_DMA_TODEVICE);
    up(&pcie_semaphore[SEM_DMA]);

    exit:
      return (ret);
}

u32 xpcie_readCfgReg (u32 byte)
{
   u32 pciReg;
   if (pci_read_config_dword(DEVICE, byte, &pciReg) < 0) {
        printk("%s: xpcie_readCfgReg: Reading PCI interface failed.", DRIVER_NAME);
        return (-1);
   }
   return (pciReg);
}

