`ifndef __NYSA_PCIE_DEFINES__
`define __NYSA_PCIE_DEFINES__

`define STATUS_BUF_ADDR       32'h00000000
`define BUFFER_READY          32'h00000001
`define WRITE_BUF_A_ADDR      32'h00000002
`define WRITE_BUF_B_ADDR      32'h00000003
`define READ_BUF_A_ADDR       32'h00000004
`define READ_BUF_B_ADDR       32'h00000005
`define BUFFER_SIZE           32'h00000006
`define PING_VALUE            32'h00000007

//The total number of items in the configuration registers
`define CONFIG_REGISTER_COUNT 8

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


//Buffer Ready Range
`define BUFFER_READY_RANGE  1:0

`endif //__NYSA_PCIE_DEFINES__
