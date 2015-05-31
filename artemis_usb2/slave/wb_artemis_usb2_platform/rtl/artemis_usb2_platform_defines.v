`ifndef __ARTEMIS_USB2_PLATFORM_DEFINES__
`define __ARTEMIS_USB2_PLATFORM_DEFINES__

`define PCIE_RESET              2
`define SATA_RESET              3
`define GTP_RX_PRE_AMP_LOW      4
`define GTP_RX_PRE_AMP_HIGH     5
`define GTP_TX_DIFF_SWING_LOW   8
`define GTP_TX_DIFF_SWING_HIGH  11
`define PCIE_RX_POLARITY        12


//Output Only
`define SATA_PLL_DETECT_K       0
`define PCIE_PLL_DETECT_K       1
`define SATA_RESET_DONE         2
`define PCIE_RESET_DONE         3
`define SATA_DCM_PLL_LOCKED     4
`define PCIE_DCM_PLL_LOCKED     5
`define SATA_RX_IDLE            6
`define PCIE_RX_IDLE            7
`define SATA_TX_IDLE            8
`define PCIE_TX_IDLE            9
`define SATA_LOSS_OF_SYNC       10
`define PCIE_LOSS_OF_SYNC       11


`endif
