#ifndef __PCIE_CTRL_H__
#define __PCIE_CTRL_H__


#include <linux/cdev.h>
#include <linux/pci.h>

//The total number of items in the configuration registers
#define CONFIG_REGISTER_COUNT 9
#define CMD_OFFSET            0x080

typedef struct
{
  bool              initialized;
  unsigned int      buffer_size;
  unsigned int      bar_addr;         //BAR 0 Physical Address
  unsigned int      bar_len;          //Length of BAR 0
  void *            virt_addr;        //Virtual Address of BAR0 Memory
  struct mutex      mutex;

  //Data Fields
  unsigned char *   status_buffer;
  dma_addr_t        status_dma_addr;

  unsigned char *   write_buffer[WRITE_BUFFER_COUNT];
  dma_addr_t        write_dma_addr[WRITE_BUFFER_COUNT];

  unsigned char *   read_buffer[READ_BUFFER_COUNT];
  dma_addr_t        read_dma_addr[READ_BUFFER_COUNT];

  //Driver Fields
  unsigned int      index;            //Where this driver is in the list of minor numbers
  struct pci_dev    *pdev;            //PCI Driver
  void *            private_data;
  struct cdev       cdev;
  struct completion complete;

  //Sys Fs Fields
	int								test;             //XXX: Just for demo
  unsigned int      config_space[CONFIG_REGISTER_COUNT];
} nysa_pcie_dev_t;

//-----------------------------------------------------------------------------
// Function Prototypes
//-----------------------------------------------------------------------------

int construct_pcie_ctr(int dev_count);
void destroy_pcie_ctr(void);

int construct_pcie_device(struct pci_dev *pdev, dev_t devno);
void destroy_pcie_device(struct pci_dev *pdev);

void set_nysa_pcie_private(int index, void * data);
void * get_nysa_pcie_private(int index);
int get_nysa_pcie_dev_index(nysa_pcie_dev_t * dev);
nysa_pcie_dev_t * get_nysa_pcie_dev(int index);

int write_register(nysa_pcie_dev_t * dev, unsigned int address, unsigned int value);
int write_command(nysa_pcie_dev_t * pdev, unsigned int address, unsigned int device_address, unsigned int value);


#endif //__PCIE_CTRL_H__
