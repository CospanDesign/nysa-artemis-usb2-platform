`ifndef __NYSA_PCIE_DEFINES__
`define __NYSA_PCIE_DEFINES__

`define HDR_STATUS_BUF_ADDR       0
`define HDR_BUFFER_READY          1
`define HDR_WRITE_BUF_A_ADDR      2
`define HDR_WRITE_BUF_B_ADDR      3
`define HDR_READ_BUF_A_ADDR       4
`define HDR_READ_BUF_B_ADDR       5
`define HDR_BUFFER_SIZE           6
`define HDR_PING_VALUE            7
`define HDR_DEV_ADDR              8

//The total number of items in the configuration registers
`define CONFIG_REGISTER_COUNT 9

`define CMD_OFFSET            32'h00000080

`define COMMAND_RESET         32'h00000080
`define PERIPHERAL_WRITE      32'h00000081
`define PERIPHERAL_WRITE_FIFO 32'h00000082
`define PERIPHERAL_READ       32'h00000083
`define PERIPHERAL_READ_FIFO  32'h00000084
`define MEMORY_WRITE          32'h00000085
`define MEMORY_READ           32'h00000086
`define DMA_WRITE             32'h00000087
`define DMA_READ              32'h00000088
`define PING                  32'h00000089
`define READ_CONFIG           32'h0000008A

//Device Select
`define SELECT_CONTROL        4'h0
`define SELECT_PERIPH         4'h1
`define SELECT_MEM            4'h2
`define SELECT_DMA            4'h3

//Status Bit
`define STATUS_BIT_READY        0
`define STATUS_BIT_WRITING      1
`define STATUS_BIT_READING      2
`define STATUS_BIT_FIFO         3
`define STATUS_BIT_PING         4
`define STATUS_BIT_READ_CFG     5
`define STATUS_BIT_UNKNOWN_CMD  6
`define STATUS_UNUSED           31:7

//Interrupt
`define NYSA_INTERRUPT_CONFIG   1


//Buffer Ready Range
`define HDR_BUFFER_READY_RANGE  1:0

`endif //__NYSA_PCIE_DEFINES__
