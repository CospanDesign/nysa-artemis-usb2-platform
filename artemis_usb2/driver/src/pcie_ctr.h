#ifndef __PCIE_CTRL_H__
#define __PCIE_CTRL_H__


#include <linux/cdev.h>
#include <linux/pci.h>
typedef struct
{
  bool              initialized;
  unsigned long     buffer_size;
  unsigned long     bar_addr;
  unsigned long     bar_len;
  unsigned long     virt_addr;
  unsigned int      index;
  struct pci_dev    *pdev;

  struct mutex       mutex;
  struct cdev       cdev;

  unsigned char *   status_buffer; 
  dma_addr_t        status_dma_addr;

  unsigned char *   write_buffer[WRITE_BUFFER_COUNT]; 
  dma_addr_t        write_dma_addr[WRITE_BUFFER_COUNT];

  unsigned char *   read_buffer[READ_BUFFER_COUNT]; 
  dma_addr_t        read_dma_addr[READ_BUFFER_COUNT];

  void *            private_data;
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

#endif //__PCIE_CTRL_H__
