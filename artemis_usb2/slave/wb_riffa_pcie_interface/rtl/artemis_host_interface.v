/*
Distributed under the MIT license.
Copyright (c) 2015 Dave McCoy (dave.mccoy@cospandesign.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

/*
 * Author:
 * Description:
 *
 * Changes:
 */

`timescale 1ps / 1ps

`define PER_SEL         0
`define MEM_SEL         1
`define DMA_SEL         2

module artemis_host_interface #(
  // Number of RIFFA Channels (Peripheral, Memory, DMA)
  parameter C_NUM_CHNL                        = 3,
  // Bit-Width from Vivado IP Generator
  parameter C_PCI_DATA_WIDTH                  = 32,
  // 4-Byte Name for this FPGA
  parameter C_MAX_PAYLOAD_BYTES               = 256,
  parameter C_LOG_NUM_TAGS                    = 8,
  parameter C_SERIAL_NUMBER                   = 64'h000000000000C594
  parameter C_FPGA_ID                         = "KC105", //??
  parameter C_INGRESS_FIFO_DEPTH              = 10,
  parameter C_EGRESS_FIFO_DEPTH               = 10
  parameter DMA_FIFO_DEPTH                    = 9

)(

  input               clk,
  input               rst,

  input               i_interrupt,          // FPGA Initiated an Interrupt (This may not be implemented yet!)
  output              o_user_lnk_up,
  output              o_pcie_rst_out,

  // Data Interface

  //Peripheral Interface
  input               i_master_ready,

  output              o_ih_reset,
  output              o_ih_ready,

  output      [31:0]  o_command,
  output      [31:0]  o_address,
  output      [31:0]  o_data,
  output      [27:0]  o_data_count,

  output              o_oh_ready,
  input               i_oh_en,

  input       [31:0]  i_status,
  input       [31:0]  i_address,
  input       [31:0]  i_data,
  input       [27:0]  i_data_count,

  //Memory Interface
  //DDR3 Control Signals
  output              ddr3_cmd_clk,
  output              ddr3_cmd_en,
  output      [2:0]   ddr3_cmd_instr,
  output      [5:0]   ddr3_cmd_bl,
  output      [29:0]  ddr3_cmd_byte_addr,
  input               ddr3_cmd_empty,
  input               ddr3_cmd_full,

  output              ddr3_wr_clk,
  output              ddr3_wr_en,
  output      [3:0]   ddr3_wr_mask,
  output      [31:0]  ddr3_wr_data,
  input               ddr3_wr_full,
  input               ddr3_wr_empty,
  input       [6:0]   ddr3_wr_count,
  input               ddr3_wr_underrun,
  input               ddr3_wr_error,

  output              ddr3_rd_clk,
  output              ddr3_rd_en,
  input       [31:0]  ddr3_rd_data,
  input               ddr3_rd_full,
  input               ddr3_rd_empty,
  input       [6:0]   ddr3_rd_count,
  input               ddr3_rd_overflow,
  input               ddr3_rd_error,



  //DMA Interface
  // Host to DMA Interface
  input               i_idma_flush,
  input               i_idma_activate,
  output              o_idma_ready,
  input               i_idma_stb,
  output      [23:0]  o_idma_size,
  output      [31:0]  o_idma_data,

  input               i_odma_flush,
  output      [1:0]   o_odma_ready,
  input       [1:0]   i_odma_activate,
  input               i_odma_stb,
  output      [23:0]  o_odma_size,
  input       [31:0]  i_odma_data,


  //Phy Interface
  input               i_pcie_phy_clk_p,
  input               i_pcie_phy_clk_n,

  output              o_pcie_phy_tx_p,
  output              o_pcie_phy_tx_n,

  input               i_pcie_phy_rx_p,
  input               i_pcie_phy_rx_n


);
//local parameters
localparam      PERIPH_BM   = (1 << `PER_SEL);
localparam      MEMORY_BM   = (1 << `MEM_SEL);
localparam      DMA_BM      = (1 << `DMA_SEL);


//registes/wires
wire    [C_NUM_CHNL-1:0]                        w_chnl_rx_clk;        // Channel read clock
wire    [C_NUM_CHNL-1:0]                        w_chnl_rx;            // Channel read receive signal
wire    [C_NUM_CHNL-1:0]                        w_chnl_rx_ack;        // Channel read received signal
wire    [C_NUM_CHNL-1:0]                        w_chnl_rx_last;       // Channel last read
wire    [(C_NUM_CHNL*`SIG_CHNL_LENGTH_W)-1:0]   w_chnl_rx_len;        // Channel read length
wire    [(C_NUM_CHNL*`SIG_CHNL_OFFSET_W)-1:0]   w_chnl_rx_off;        // Channel read offset
wire    [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0]     w_chnl_rx_data;       // Channel read data
wire    [C_NUM_CHNL-1:0]                        w_chnl_rx_data_valid; // Channel read data valid
wire    [C_NUM_CHNL-1:0]                        w_chnl_rx_data_ren;   // Channel read data has been recieved

wire    [C_NUM_CHNL-1:0]                        w_chnl_tx_clk;        // Channel write clock
wire    [C_NUM_CHNL-1:0]                        w_chnl_tx;            // Channel write receive signal
wire    [C_NUM_CHNL-1:0]                        w_chnl_tx_ack;        // Channel write acknowledgement signal
wire    [C_NUM_CHNL-1:0]                        w_chnl_tx_last;       // Channel last write
wire    [(C_NUM_CHNL*`SIG_CHNL_LENGTH_W)-1:0]   w_chnl_tx_len;        // Channel write length (in 32 bit words)
wire    [(C_NUM_CHNL*`SIG_CHNL_OFFSET_W)-1:0]   w_chnl_tx_off;        // Channel write offset
wire    [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0]     w_chnl_tx_data;       // Channel write data
wire    [C_NUM_CHNL-1:0]                        w_chnl_tx_data_valid; // Channel write data valid
wire    [C_NUM_CHNL-1:0]                        w_chnl_tx_data_ren;   // Channel write data has been recieved


reg     [3:0]                                   w_ingress_sel;
reg     [3:0]                                   w_egress_sel;

wire                                            w_per_iriffa_en;
wire                                            w_per_iriffa_ack;
wire                                            w_per_iriffa_last;
wire    [`SIG_CHNL_LENGTH_W - 1:0]              w_per_iriffa_len;
wire    [`SIG_CHNL_OFFSET_W - 1:0]              w_per_iriffa_off;
wire    [C_PCI_DATA_WIDTH - 1:0]                w_per_iriffa_data;
wire                                            w_per_iriffa_data_valid;
wire                                            w_per_iriffa_data_ren;

wire                                            w_mem_iriffa_en;
wire                                            w_mem_iriffa_ack;
wire                                            w_mem_iriffa_last;
wire    [`SIG_CHNL_LENGTH_W - 1:0]              w_mem_iriffa_len;
wire    [`SIG_CHNL_OFFSET_W - 1:0]              w_mem_iriffa_off;
wire    [C_PCI_DATA_WIDTH - 1:0]                w_mem_iriffa_data;
wire                                            w_mem_iriffa_data_valid;
wire                                            w_mem_iriffa_data_ren;

wire                                            w_dma_iriffa_en;
wire                                            w_dma_iriffa_ack;
wire                                            w_dma_iriffa_last;
wire    [`SIG_CHNL_LENGTH_W - 1:0]              w_dma_iriffa_len;
wire    [`SIG_CHNL_OFFSET_W - 1:0]              w_dma_iriffa_off;
wire    [C_PCI_DATA_WIDTH - 1:0]                w_dma_iriffa_data;
wire                                            w_dma_iriffa_data_valid;
wire                                            w_dma_iriffa_data_ren;

wire                                            w_per_eriffa_en;
wire                                            w_per_eriffa_ack;
wire                                            w_per_eriffa_last;
wire    [`SIG_CHNL_LENGTH_W - 1:0]              w_per_eriffa_len;
wire    [`SIG_CHNL_OFFSET_W - 1:0]              w_per_eriffa_off;
wire    [C_PCI_DATA_WIDTH - 1:0]                w_per_eriffa_data;
wire                                            w_per_eriffa_data_valid;
wire                                            w_per_eriffa_data_ren;

wire                                            w_mem_eriffa_en;
wire                                            w_mem_eriffa_ack;
wire                                            w_mem_eriffa_last;
wire    [`SIG_CHNL_LENGTH_W - 1:0]              w_mem_eriffa_len;
wire    [`SIG_CHNL_OFFSET_W - 1:0]              w_mem_eriffa_off;
wire    [C_PCI_DATA_WIDTH - 1:0]                w_mem_eriffa_data;
wire                                            w_mem_eriffa_data_valid;
wire                                            w_mem_eriffa_data_ren;

wire                                            w_dma_eriffa_en;
wire                                            w_dma_eriffa_ack;
wire                                            w_dma_eriffa_last;
wire    [`SIG_CHNL_LENGTH_W - 1:0]              w_dma_eriffa_len;
wire    [`SIG_CHNL_OFFSET_W - 1:0]              w_dma_eriffa_off;
wire    [C_PCI_DATA_WIDTH - 1:0]                w_dma_eriffa_data;
wire                                            w_dma_eriffa_data_valid;
wire                                            w_dma_eriffa_data_ren;

wire                                            w_ingress_per_sel;
wire                                            w_ingress_mem_sel;
wire                                            w_ingress_dma_sel;

wire                                            w_egress_per_sel;
wire                                            w_egress_mem_sel;
wire                                            w_egress_dma_sel;

wire    [1:0]                                   w_ingress_sel;
wire    [1:0]                                   w_egress_sel;



//DDR3 Controller PPFIFO Interface

wire    [27:0]                                  ddr3_cmd_word_addr;
wire                                            if_write_strobe;
wire    [1:0]                                   if_write_ready;
wire    [1:0]                                   if_write_activate;
wire    [23:0]                                  if_write_fifo_size;


wire                                            of_read_strobe;
wire                                            of_read_ready;
wire                                            of_read_activate;
wire    [23:0]                                  of_read_size;
wire    [31:0]                                  of_read_data;

wire    [1:0]                                   w_dma_ingress_rdy;
wire    [23:0]                                  w_dma_ingress_size;
wire    [1:0]                                   w_dma_ingress_act;
wire                                            w_dma_ingress_stb;
wire    [31:0]                                  w_dma_ingress_data;

wire                                            w_dma_egress_rdy;
wire    [23:0]                                  w_dma_egress_size;
wire                                            w_dma_egress_act;
wire                                            w_dma_egress_stb;
wire    [31:0]                                  w_dma_egress_data;

//submodules
wire                                            w_mem_write_en;
wire                                            w_mem_read_en;
reg     [31:0]                                  w_mem_adr;

artemis_pcie_interface #(
  .C_NUM_CHNL                                  (C_NUM_CHNL               ),
  .C_PCI_DATA_WIDTH                            (C_PCI_DATA_WIDTH         ),
  .C_MAX_PAYLOAD_BYTES                         (C_MAX_PAYLOAD_BYTES      ),
  .C_LOG_NUM_TAGS                              (C_LOG_NUM_TAGS           ),
  .C_SERIAL_NUMBER                             (C_SERIAL_NUMBER          ),
  .C_FPGA_ID                                   (C_FPGA_ID                )
) pcie_interface (
  .i_interrupt                                 (i_interrupt              ),
  .o_user_lnk_up                               (o_user_lnk_up            ),

  .o_pcie_rst_out                              (o_pcie_rst_out           ),

  .i_chnl_rx_clk                               (w_chnl_rx_clk            ),
  .o_chnl_rx                                   (w_chnl_rx                ),
  .i_chnl_rx_ack                               (w_chnl_rx_ack            ),
  .o_chnl_rx_last                              (w_chnl_rx_last           ),
  .o_chnl_rx_len                               (w_chnl_rx_len            ),
  .o_chnl_rx_off                               (w_chnl_rx_off            ),
  .o_chnl_rx_data                              (w_chnl_rx_data           ),
  .o_chnl_rx_data_valid                        (w_chnl_rx_data_valid     ),
  .i_chnl_rx_data_ren                          (w_chnl_rx_data_ren       ),

  .i_chnl_tx_clk                               (w_chnl_tx_clk            ),
  .i_chnl_tx                                   (w_chnl_tx                ),
  .o_chnl_tx_ack                               (w_chnl_tx_ack            ),
  .i_chnl_tx_last                              (w_chnl_tx_last           ),
  .i_chnl_tx_len                               (w_chnl_tx_len            ),
  .i_chnl_tx_off                               (w_chnl_tx_off            ),
  .i_chnl_tx_data                              (w_chnl_tx_data           ),
  .i_chnl_tx_data_valid                        (w_chnl_tx_data_valid     ),
  .o_chnl_tx_data_ren                          (w_chnl_tx_data_ren       )

  .i_pcie_phy_clk_p                            (i_pcie_phy_clk_p         ),
  .i_pcie_phy_clk_n                            (i_pcie_phy_clk_n         ),

  .o_pcie_phy_tx_p                             (o_pcie_phy_tx_p          ),
  .o_pcie_phy_tx_n                             (o_pcie_phy_tx_n          ),

  .i_pcie_phy_rx_p                             (i_pcie_phy_rx_p          ),
  .i_pcie_phy_rx_n                             (i_pcie_phy_rx_n          )
);


//DDR3 Memory Controller
ddr3_controller dc (
  .clk                (clk                   ),
  .rst                (rst                   ),

  .write_address      (w_mem_adr[27:0]       ),
  .write_en           (w_mem_write_en        ),
  .read_address       (w_mem_adr[27:0]       ),
  .read_en            (w_mem_read_en         ),

  .if_write_strobe    (i_mem_ingress_stb     ),
  .if_write_data      (o_mem_ingress_data    ),
  .if_write_ready     (i_mem_ingress_rdy     ),
  .if_write_activate  (o_mem_ingress_act     ),
  .if_write_fifo_size (o_mem_ingress_size    ),
//  .if_starved         (                      ),

  .of_read_strobe     (o_mem_egress_stb      ),
  .of_read_ready      (i_mem_egress_rdy      ),
  .of_read_activate   (o_mem_egress_act      ),
  .of_read_size       (i_mem_egress_size     ),
  .of_read_data       (o_mem_egress_data     ),

  .cmd_en             (ddr3_cmd_en           ),
  .cmd_instr          (ddr3_cmd_instr        ),
  .cmd_bl             (ddr3_cmd_bl           ),
  .cmd_word_addr      (ddr3_cmd_word_addr    ),
  .cmd_empty          (ddr3_cmd_empty        ),
  .cmd_full           (ddr3_cmd_full         ),

  .wr_en              (ddr3_wr_en            ),
  .wr_mask            (ddr3_wr_mask          ),
  .wr_data            (ddr3_wr_data          ),
  .wr_full            (ddr3_wr_full          ),
  .wr_empty           (ddr3_wr_empty         ),
  .wr_count           (ddr3_wr_count         ),
  .wr_underrun        (ddr3_wr_underrun      ),
  .wr_error           (ddr3_wr_error         ),

  .rd_en              (ddr3_rd_en            ),
  .rd_data            (ddr3_rd_data          ),
  .rd_full            (ddr3_rd_full          ),
  .rd_empty           (ddr3_rd_empty         ),
  .rd_count           (ddr3_rd_count         ),
  .rd_overflow        (ddr3_rd_overflow      ),
  .rd_error           (ddr3_rd_error         )


);

//Ingress PPFIFO
ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (DMA_FIFO_DEPTH             )
) dma_ingress_fifo (
  .reset                      (o_pcie_rst_out || rst      ),

  //Write Side (From PCIE Core)
  .write_clock                (clk                        ),
  .write_ready                (w_dma_ingress_rdy          ),
  .write_activate             (w_dma_ingress_act          ),
  .write_fifo_size            (w_dma_ingress_size         ),
  .write_strobe               (w_dma_ingress_stb          ),
  .write_data                 (w_dma_ingress_data         ),

  //Read Side (To FPGA)
  .read_clock                 (clk                        ),
  .read_ready                 (o_idma_ready               ),
  .read_activate              (i_idma_activate            ),
  .read_count                 (o_idma_size                ),
  .read_strobe                (o_idma_stb                 ),
  .read_data                  (o_idma_data                )
);

//Egress PPFIFO
ppfifo #(
  .DATA_WIDTH                 (32                         ),
  .ADDRESS_WIDTH              (DMA_FIFO_DEPTH             )
) dma_ingress_fifo (
  .reset                      (o_pcie_rst_out || rst      ),

  //Write Side (From FPGA)
  .write_clock                (clk                        ),
  .write_ready                (o_odma_ready               ),
  .write_activate             (i_odma_activate            ),
  .write_fifo_size            (i_odma_stb                 ),
  .write_strobe               (o_odma_size                ),
  .write_data                 (i_odma_data                ),

  //Read Side (To PCIE Core)
  .read_clock                 (clk                        ),
  .read_ready                 (w_dma_egress_rdy           ),
  .read_activate              (w_dma_egress_act           ),
  .read_count                 (w_dma_egress_size          ),
  .read_strobe                (w_dma_egress_stb           ),
  .read_data                  (w_dma_egress_data          )
);



riffa_host_interface r_hi (
  .clk                     (clk                     ),
  .rst                     (rst                     ),
  .rst                     (o_pcie_rst_out || rst   ),

  .o_mem_adr               (w_mem_adr               ),

  .o_mem_write_en          (w_mem_write_en          ),
  .o_mem_read_en           (w_mem_read_en           ),


  //Interface Select
  .i_riffa_ingress_sel     (w_chnl_rx               ),
  .o_riffa_egress_sel      (w_chnl_tx               ),

  //RIFFA Interface
  .i_per_iriffa_en         (w_per_iriffa_en         ),
  .o_per_iriffa_ack        (w_per_iriffa_ack        ),
  .i_per_iriffa_last       (w_per_iriffa_last       ),
  .i_per_iriffa_len        (w_per_iriffa_len        ),
  .i_per_iriffa_off        (w_per_iriffa_off        ),
  .i_per_iriffa_data       (w_per_iriffa_data       ),
  .i_per_iriffa_data_valid (w_per_iriffa_data_valid ),
  .o_per_iriffa_data_ren   (w_per_iriffa_data_ren   ),


  .o_per_eriffa_en         (w_per_eriffa_en         ),
  .i_per_eriffa_ack        (w_per_eriffa_ack        ),
  .o_per_eriffa_last       (w_per_eriffa_last       ),
  .o_per_eriffa_len        (w_per_eriffa_len        ),
  .o_per_eriffa_off        (w_per_eriffa_off        ),
  .o_per_eriffa_data       (w_per_eriffa_data       ),
  .o_per_eriffa_data_valid (w_per_eriffa_data_valid ),
  .i_per_eriffa_data_ren   (w_per_eriffa_data_ren   ),


  .i_mem_iriffa_en         (w_mem_iriffa_en         ),
  .o_mem_iriffa_ack        (w_mem_iriffa_ack        ),
  .i_mem_iriffa_last       (w_mem_iriffa_last       ),
  .i_mem_iriffa_len        (w_mem_iriffa_len        ),
  .i_mem_iriffa_off        (w_mem_iriffa_off        ),
  .i_mem_iriffa_data       (w_mem_iriffa_data       ),
  .i_mem_iriffa_data_valid (w_mem_iriffa_data_valid ),
  .o_mem_iriffa_data_ren   (w_mem_iriffa_data_ren   ),


  .o_mem_eriffa_en         (w_mem_eriffa_en         ),
  .i_mem_eriffa_ack        (w_mem_eriffa_ack        ),
  .o_mem_eriffa_last       (w_mem_eriffa_last       ),
  .o_mem_eriffa_len        (w_mem_eriffa_len        ),
  .o_mem_eriffa_off        (w_mem_eriffa_off        ),
  .o_mem_eriffa_data       (w_mem_eriffa_data       ),
  .o_mem_eriffa_data_valid (w_mem_eriffa_data_valid ),
  .i_mem_eriffa_data_ren   (w_mem_eriffa_data_ren   ),


  .i_dma_iriffa_en         (w_dma_iriffa_en         ),
  .o_dma_iriffa_ack        (w_dma_iriffa_ack        ),
  .i_dma_iriffa_last       (w_dma_iriffa_last       ),
  .i_dma_iriffa_len        (w_dma_iriffa_len        ),
  .i_dma_iriffa_off        (w_dma_iriffa_off        ),
  .i_dma_iriffa_data       (w_dma_iriffa_data       ),
  .i_dma_iriffa_data_valid (w_dma_iriffa_data_valid ),
  .o_dma_iriffa_data_ren   (w_dma_iriffa_data_ren   ),

  .o_dma_eriffa_en         (w_dma_eriffa_en         ),
  .i_dma_eriffa_ack        (w_dma_eriffa_ack        ),
  .o_dma_eriffa_last       (w_dma_eriffa_last       ),
  .o_dma_eriffa_len        (w_dma_eriffa_len        ),
  .o_dma_eriffa_off        (w_dma_eriffa_off        ),
  .o_dma_eriffa_data       (w_dma_eriffa_data       ),
  .o_dma_eriffa_data_valid (w_dma_eriffa_data_valid ),
  .i_dma_eriffa_data_ren   (w_dma_eriffa_data_ren   ),


  //Memory Interface
  .i_mem_ingress_rdy       (i_mem_ingress_rdy       ),
  .i_mem_ingress_size      (i_mem_ingress_size      ),
  .o_mem_ingress_act       (o_mem_ingress_act       ),
  .o_mem_ingress_stb       (o_mem_ingress_stb       ),
  .o_mem_ingress_data      (o_mem_ingress_data      ),

  .i_mem_egress_rdy        (i_mem_egress_rdy        ),
  .i_mem_egress_size       (i_mem_egress_size       ),
  .o_mem_egress_act        (o_mem_egress_act        ),
  .o_mem_egress_stb        (o_mem_egress_stb        ),
  .i_mem_egress_data       (i_mem_egress_data       ),

  //DMA Interface
  .i_dma_ingress_rdy       (w_dma_ingress_rdy       ),
  .i_dma_ingress_size      (w_dma_ingress_size      ),
  .o_dma_ingress_act       (w_dma_ingress_act       ),
  .o_dma_ingress_stb       (w_dma_ingress_stb       ),
  .o_dma_ingress_data      (w_dma_ingress_data      ),

  .i_dma_egress_rdy        (w_dma_egress_rdy        ),
  .i_dma_egress_size       (w_dma_egress_size       ),
  .o_dma_egress_act        (w_dma_egress_act        ),
  .o_dma_egress_stb        (w_dma_egress_stb        ),
  .i_dma_egress_data       (w_dma_egress_data       ),

  //Wishbone Master Interface
  .i_master_ready          (i_master_ready          ),
  .o_ready                 (o_ih_ready              ),
  .o_ih_rst                (o_ih_rst                ),
  .o_command               (o_command               ),
  .o_address               (o_address               ),
  .o_data                  (o_data                  ),
  .o_data_count            (o_data_count            ),


  .o_out_ready             (o_oh_ready              ),
  .i_en                    (i_oh_en                 ),
  .i_status                (i_status                ),
  .i_address               (i_address               ),
  .i_data                  (i_data                  ),
  .i_data_count            (i_data_count            )
);


//Interface to Master

//Interface to Memory

//Interface to DMA

//asynchronous logic

//Ingress
assign  w_per_iriffa_en                 = (w_chnl_rx == PERIPH_SEL);
assign  w_mem_iriffa_en                 = (w_chnl_rx == MEMORY_SEL);
assign  w_dma_iriffa_en                 = (w_chnl_rx == DMA_SEL);

assign  w_per_iriffa_len                = w_chnl_rx_len[(`SIG_CHNL_LENGTH_W * 1) - 1: (`SIG_CHNL_LENGTH_W * 0)];
assign  w_mem_iriffa_len                = w_chnl_rx_len[(`SIG_CHNL_LENGTH_W * 2) - 1: (`SIG_CHNL_LENGTH_W * 1)];
assign  w_dma_iriffa_len                = w_chnl_rx_len[(`SIG_CHNL_LENGTH_W * 3) - 1: (`SIG_CHNL_LENGTH_W * 2)];

assign  w_per_iriffa_off                = w_chnl_rx_off[(`SIG_CHNL_OFFSET_W * 1) - 1: (`SIG_CHNL_OFFSET_W * 0)];
assign  w_mem_iriffa_off                = w_chnl_rx_off[(`SIG_CHNL_OFFSET_W * 2) - 1: (`SIG_CHNL_OFFSET_W * 1)];
assign  w_dma_iriffa_off                = w_chnl_rx_off[(`SIG_CHNL_OFFSET_W * 3) - 1: (`SIG_CHNL_OFFSET_W * 2)];

assign  w_per_iriffa_data               = w_chnl_rx_data[(C_PCI_DATA_WIDTH * 1) - 1: (C_PCI_DATA_WIDTH * 0)];
assign  w_mem_iriffa_data               = w_chnl_rx_data[(C_PCI_DATA_WIDTH * 2) - 1: (C_PCI_DATA_WIDTH * 1)];
assign  w_dma_iriffa_data               = w_chnl_rx_data[(C_PCI_DATA_WIDTH * 3) - 1: (C_PCI_DATA_WIDTH * 2)];

assign  w_per_iriffa_data_valid         = w_chnl_rx_data_valid[PERIPH_SEL];
assign  w_mem_iriffa_data_valid         = w_chnl_rx_data_valid[MEMORY_SEL];
assign  w_dma_iriffa_data_valid         = w_chnl_rx_data_valid[DMA_SEL];

assign  w_per_iriffa_last               = w_chnl_rx_last[PERIPH_SEL];
assign  w_mem_iriffa_last               = w_chnl_rx_last[MEMORY_SEL];
assign  w_dma_iriffa_last               = w_chnl_rx_last[DMA_SEL];

assign  w_chnl_rx_ack[PERIPH_SEL]       = w_per_iriffa_ack;
assign  w_chnl_rx_ack[MEMORY_SEL]       = w_mem_iriffa_ack;
assign  w_chnl_rx_ack[DMA_SEL]          = w_dma_iriffa_ack;

assign  w_chnl_rx_data_ren[PERIPH_SEL]  = w_per_iriffa_data_ren;
assign  w_chnl_rx_data_ren[MEMORY_SEL]  = w_mem_iriffa_data_ren;
assign  w_chnl_rx_data_ren[DMA_SEL]     = w_dma_iriffa_data_ren;




//RIFFA Egress Demultiplexing
assign  w_per_eriffa_en                 = (w_chnl_tx == PERIPH_SEL);
assign  w_mem_eriffa_en                 = (w_chnl_tx == MEMORY_SEL);
assign  w_dma_eriffa_en                 = (w_chnl_tx == DMA_SEL);

assign  w_per_eriffa_ack                = w_chnl_tx_ack[PERIPH_SEL];
assign  w_mem_eriffa_ack                = w_chnl_tx_ack[MEMORY_SEL];
assign  w_dma_eriffa_ack                = w_chnl_tx_ack[DMA_SEL];

assign  w_per_eriffa_data_ren           = w_chnl_tx_data_ren[PERIPH_SEL];
assign  w_mem_eriffa_data_ren           = w_chnl_tx_data_ren[MEMORY_SEL];
assign  w_dma_eriffa_data_ren           = w_chnl_tx_data_ren[DMA_SEL];

assign  w_chnl_tx_len[(`SIG_CHNL_LENGTH_W * 1) - 1: (`SIG_CHNL_LENGTH_W * 0)] = w_per_eriffa_len;
assign  w_chnl_tx_len[(`SIG_CHNL_LENGTH_W * 2) - 1: (`SIG_CHNL_LENGTH_W * 1)] = w_mem_eriffa_len;
assign  w_chnl_tx_len[(`SIG_CHNL_LENGTH_W * 3) - 1: (`SIG_CHNL_LENGTH_W * 2)] = w_dma_eriffa_len;

assign  w_chnl_tx_off[(`SIG_CHNL_OFFSET_W * 1) - 1: (`SIG_CHNL_OFFSET_W * 0)] = w_per_eriffa_off;
assign  w_chnl_tx_off[(`SIG_CHNL_OFFSET_W * 2) - 1: (`SIG_CHNL_OFFSET_W * 1)] = w_mem_eriffa_off;
assign  w_chnl_tx_off[(`SIG_CHNL_OFFSET_W * 3) - 1: (`SIG_CHNL_OFFSET_W * 2)] = w_dma_eriffa_off;

assign  w_chnl_tx_data[(C_PCI_DATA_WIDTH * 1) - 1: (C_PCI_DATA_WIDTH * 0)]    = w_per_eriffa_data;
assign  w_chnl_tx_data[(C_PCI_DATA_WIDTH * 2) - 1: (C_PCI_DATA_WIDTH * 1)]    = w_mem_eriffa_data;
assign  w_chnl_tx_data[(C_PCI_DATA_WIDTH * 3) - 1: (C_PCI_DATA_WIDTH * 2)]    = w_dma_eriffa_data;

assign  w_chnl_tx_last[PERIPH_SEL]       = w_per_eriffa_last;
assign  w_chnl_tx_last[MEMORY_SEL]       = w_mem_eriffa_last;
assign  w_chnl_tx_last[DMA_SEL]          = w_dma_eriffa_last;

assign  w_chnl_tx_data_valid[PERIPH_SEL] = w_per_eriffa_data_valid;
assign  w_chnl_tx_data_valid[MEMORY_SEL] = w_mem_eriffa_data_valid;
assign  w_chnl_tx_data_valid[DMA_SEL]    = w_dma_eriffa_data_valid;


//synchronous logic

endmodule
