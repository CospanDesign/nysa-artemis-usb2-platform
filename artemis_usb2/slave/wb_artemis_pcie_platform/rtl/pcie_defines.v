`ifndef __PCIE_DEFINES__
`define __PCIE_DEFINES__


//Size of the packets
`define PCIE_FMT_RANGE 31:29

`define PCIE_FMT_3DW_NO_DATA  3'b000
`define PCIE_FMT_4DW_NO_DATA  3'b001
`define PCIE_FMT_3DW_DATA     3'b010
`define PCIE_FMT_4DW_DATA     3'b011
`define PCIE_FMT_TLP_PREFIX   3'b100

//Type of packet
`define PCIE_TYPE_RANGE 31:24

`define PCIE_MRD          8'b00X00000
`define PCIE_MRDLK        8'b00X00001
`define PCIE_MWR          8'b01X00000
`define PCIE_IORD         8'b0X000010
`define PCIE_IOWR         8'b01000010
`define PCIE_CFGRD0       8'b00000100
`define PCIE_CFGWR0       8'b01000100
`define PCIE_CFGRD1       8'b00000101
`define PCIE_CFGWR1       8'b01000101
`define PCIE_TCFGRD       8'b00011011
`define PCIE_TCFGWR       8'b01011011
`define PCIE_MSG          8'b00110XXX
`define PCIE_MSG_D        8'b01110XXX
`define PCIE_CPL          8'b00001010
`define PCIE_CPL_D        8'b01001010
`define PCIE_CPLLK        8'b00001011
`define PCIE_CPLDLK       8'b01001011
`define PCIE_FETCH_ADD    8'b01X01100
`define PCIE_SWAP         8'b01X01101
`define PCIE_CAS          8'b01X01110
`define PCIE_LPRF         8'b1000XXXX
`define PCIE_EPRF         8'b1001XXXX

`define PCIE_TYPE_MRD 5'b00000;
`define PCIE_TYPE_MWR 5'b00000;

//Number of DWORDs of packet
`define PCIE_DWORD_PKT_CNT_RANGE 9:0

//For our current architecture (Spartan 6) the max payload size is 512
//THIS MAY CHANGE FOR KINTEX!
`define MAX_PAYLOAD_SIZE  512

//Configuration
`define CFG_REGISTER_RANGE 11:2

`define BAR_ADDR0 10'h010
`define BAR_ADDR1 10'h014
`define BAR_ADDR2 10'h018
`define BAR_ADDR3 10'h01C
`define BAR_ADDR4 10'h020
`define BAR_ADDR5 10'h024

`endif //__PCIE_DEFINES__
