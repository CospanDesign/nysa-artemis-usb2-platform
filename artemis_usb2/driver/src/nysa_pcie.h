#ifndef __NYSA_PCIE_MAIN_H__
#define __NYSA_PCIE_MAIN_H__

#define MODULE_NAME                 "nysa_pcie"

#define PCI_VENDOR_XILINX           0x10EE
#define PCI_DEVICE_XILINX_PCIE_RAM  0x0007

//Module Specific Defines
#define MAX_DEVICES                 8
#define MINOR_NUM_START             0


#define WRITE_BUFFER_COUNT          2
#define READ_BUFFER_COUNT           2

#define NYSA_PCIE_BUFFER_SIZE       4096
#define NYSA_MAX_PACKET_SIZE        512


#define CONTROL_BAR                 0


#define HDR_STATUS_BUF_ADDR         0
#define HDR_BUFFER_READY            1
#define HDR_WRITE_BUF_A_ADDR        2
#define HDR_WRITE_BUF_B_ADDR        3
#define HDR_READ_BUF_A_ADDR         4
#define HDR_READ_BUF_B_ADDR         5
#define HDR_BUFFER_SIZE             6
#define HDR_PING_VALUE              7

//The total number of items in the configuration registers
#define CONFIG_REGISTER_COUNT       8

#define CMD_OFFSET                  0x0080

#define COMMAND_RESET               0x0080
#define PERIPHERAL_WRITE            0x0081
#define PERIPHERAL_WRITE_FIFO       0x0082
#define PERIPHERAL_READ             0x0083
#define PERIPHERAL_READ_FIFO        0x0084
#define MEMORY_WRITE                0x0085
#define MEMORY_READ                 0x0086
#define DMA_WRITE                   0x0087
#define DMA_READ                    0x0088
#define PING                        0x0089
#define READ_CONFIG                 0x008A


//Boiler Plate Defines
#define SUCCESS                     0
#define CRIT_ERR                    -1


#ifdef DEBUG
 #define mod_info( args... ) \
    do { printk( KERN_INFO "%s - %s : ", MODULE_NAME , __FUNCTION__ );\
    printk( args ); } while(0)
 #define mod_info_dbg( args... ) \
    do { printk( KERN_INFO "%s - %s : ", MODULE_NAME , __FUNCTION__ );\
    printk( args ); } while(0)
#else
 #define mod_info( args... ) \
    do { printk( KERN_INFO "%s: ", MODULE_NAME );\
    printk( args ); } while(0)
 #define mod_info_dbg( args... )
#endif

#define mod_crit( args... ) \
    do { printk( KERN_CRIT "%s: ", MODULE_NAME );\
    printk( args ); } while(0)



#endif //__NYSA_PCIE_MAIN_H__
