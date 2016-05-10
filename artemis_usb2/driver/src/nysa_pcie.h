#ifndef __NYSA_PCIE_MAIN_H__
#define __NYSA_PCIE_MAIN_H__

#define MODULE_NAME                 "nysa_pcie"

#define PCI_VENDOR_XILINX           0x10EE
#define PCI_DEVICE_XILINX_PCIE_RAM  0x0007
//#define PCI_DEVICE_XILINX_PCIE_RAM  0x0008

//Module Specific Defines
#define MAX_DEVICES                 8
#define MINOR_NUM_START             0


#define WRITE_BUFFER_COUNT          2
#define READ_BUFFER_COUNT           2

#define NYSA_PCIE_BUFFER_SIZE       4096
#define NYSA_MAX_PACKET_SIZE        256


#define CONTROL_BAR                 0


//Boiler Plate Defines
#define SUCCESS                     0
#define CRIT_ERR                    -1

#define DEBUG 1

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
