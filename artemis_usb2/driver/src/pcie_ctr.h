#ifndef __PCIE_CTRL_H__
#define __PCIE_CTRL_H__


#include <linux/cdev.h>
#include <linux/pci.h>
#include <linux/workqueue.h>


//The total number of items in the configuration registers
#define CONFIG_REGISTER_COUNT 9
#define CMD_OFFSET            0x080
#define NUM_BUFFERS           2

struct _nysa_pcie_dev_t;

typedef struct
{
  struct work_struct work;
  int index;
} buffer_work_t;

typedef struct _nysa_pcie_dev_t
{
  bool                    initialized;
  unsigned int            buffer_size;
  unsigned int            bar_addr;         //BAR 0 Physical Address
  unsigned int            bar_len;          //Length of BAR 0
  void *                  virt_addr;        //Virtual Address of BAR0 Memory
                         
  //Data References      
  size_t                  user_data_count;
  char *                  user_data_buf;
                         
  //Data Fields          
  unsigned char *         status_buffer;
  dma_addr_t              status_dma_addr;
                         
  unsigned char *         write_buffer[WRITE_BUFFER_COUNT];
  dma_addr_t              write_dma_addr[WRITE_BUFFER_COUNT];
                         
  unsigned char *         read_buffer[READ_BUFFER_COUNT];
  dma_addr_t              read_dma_addr[READ_BUFFER_COUNT];
                         
  //Driver Fields        
  unsigned int            index;            //Where this driver is in the list of minor numbers
  struct pci_dev          *pdev;            //PCI Driver
  void *                  private_data;
  struct cdev             cdev;
  struct completion       read_complete;         //Used to block user applications when reading

  struct workqueue_struct *workqueue;
  buffer_work_t           buf_work[NUM_BUFFERS];

  //Sys Fs Fields
	int									    test;             //XXX: Just for demo
  unsigned int            config_space[CONFIG_REGISTER_COUNT];
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
int write_command(nysa_pcie_dev_t * pdev, unsigned int command, unsigned int device_address, unsigned int value);

ssize_t nysa_pcie_read_data(nysa_pcie_dev_t *dev, char * user_buf, size_t count);

#endif //__PCIE_CTRL_H__
