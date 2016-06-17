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

module artemis_pcie_host_interface #(
  // Number of RIFFA Channels (Peripheral, Memory, DMA)
  // Bit-Width from Vivado IP Generator
  // 4-Byte Name for this FPGA
  parameter DMA_FIFO_DEPTH                    = 9

)(

  input               clk,
  input               rst,

  input               i_interrupt,          // FPGA Initiated an Interrupt (This may not be implemented yet!)
  output              o_user_lnk_up,
  output              o_pcie_rst_out,

  input               i_pcie_reset,
  output              o_pcie_wake_n,

  // Data Interface
  //Peripheral Interface
  input               i_master_ready,

  output              o_ih_reset,
  output              o_ih_ready,

  output      [31:0]  o_in_command,
  output      [31:0]  o_in_address,
  output      [31:0]  o_in_data,
  output      [27:0]  o_in_data_count,

  output              o_oh_ready,
  input               i_oh_en,

  input       [31:0]  i_out_status,
  input       [31:0]  i_out_address,
  input       [31:0]  i_out_data,
  input       [27:0]  i_out_data_count,

  input       [31:0]  i_usr_interrupt_value,

  output   [3:0]      o_ih_state,
  output   [3:0]      o_oh_state,

  //Memory Interface
  //DDR3 Control Signals
  output              o_ddr3_cmd_clk,
  output              o_ddr3_cmd_en,
  output      [2:0]   o_ddr3_cmd_instr,
  output      [5:0]   o_ddr3_cmd_bl,
  output      [29:0]  o_ddr3_cmd_byte_addr,
  input               i_ddr3_cmd_empty,
  input               i_ddr3_cmd_full,

  output              o_ddr3_wr_clk,
  output              o_ddr3_wr_en,
  output      [3:0]   o_ddr3_wr_mask,
  output      [31:0]  o_ddr3_wr_data,
  input               i_ddr3_wr_full,
  input               i_ddr3_wr_empty,
  input       [6:0]   i_ddr3_wr_count,
  input               i_ddr3_wr_underrun,
  input               i_ddr3_wr_error,

  output              o_ddr3_rd_clk,
  output              o_ddr3_rd_en,
  input       [31:0]  i_ddr3_rd_data,
  input               i_ddr3_rd_full,
  input               i_ddr3_rd_empty,
  input       [6:0]   i_ddr3_rd_count,
  input               i_ddr3_rd_overflow,
  input               i_ddr3_rd_error,

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

  output      [7:0]   o_cfg_read_exec,
  output      [3:0]   o_cfg_sm_state,
  output      [3:0]   o_sm_state,
  output      [7:0]   o_ingress_count,
  output      [3:0]   o_ingress_state,
  output      [7:0]   o_ingress_ri_count,
  output      [7:0]   o_ingress_ci_count,
  output      [31:0]  o_ingress_cmplt_count,
  output      [31:0]  o_ingress_addr,


  output      [31:0]  o_id_value,
  output      [31:0]  o_command_value,
  output      [31:0]  o_count_value,
  output      [31:0]  o_address_value,

  output              o_per_fifo_sel,
  output              o_mem_fifo_sel,
  output              o_dma_fifo_sel,

  output              o_write_flag,
  output              o_read_flag,
  output      [31:0]  o_debug_data,

  //PCIE Interface
  input               i_pcie_phy_clk_p,
  input               i_pcie_phy_clk_n,

  output              o_pcie_phy_tx_p,
  output              o_pcie_phy_tx_n,

  input               i_pcie_phy_rx_p,
  input               i_pcie_phy_rx_n
);
//local parameters

//Registers/Wires
wire                                            w_write_fin;
wire                                            w_read_fin;

wire                                            w_mem_fin;
wire                                            w_dma_write_fin;
reg                                             r_dma_read_fin;

wire                                            o_ing_per_fin;
wire                                            o_eng_per_fin;

//DDR3 Controller PPFIFO Interface
wire    [27:0]                                  o_ddr3_cmd_word_addr;

wire                                            w_mem_ingress_rdy;
wire    [23:0]                                  w_mem_ingress_size;
wire                                            w_mem_ingress_act;
wire                                            w_mem_ingress_stb;
wire    [31:0]                                  w_mem_ingress_data;

wire    [1:0]                                   w_mem_egress_rdy;
wire    [1:0]                                   w_mem_egress_act;
wire    [23:0]                                  w_mem_egress_size;
wire                                            w_mem_egress_stb;
wire    [31:0]                                  w_mem_egress_data;

//Ingress
wire                                            w_per_ingress_rdy;
wire                                            w_per_ingress_act;
wire    [23:0]                                  w_per_ingress_size;
wire                                            w_per_ingress_stb;
wire    [31:0]                                  w_per_ingress_data;

//Egress FIFO
wire    [1:0]                                   w_per_egress_rdy;
wire    [1:0]                                   w_per_egress_act;
wire    [23:0]                                  w_per_egress_size;
wire                                            w_per_egress_stb;
wire    [31:0]                                  w_per_egress_data;

//Single PCIE PPFIFO Interface
//Ingress
wire                                            w_pcie_ingress_rd_rdy;
wire                                            w_pcie_ingress_rd_act;
wire    [23:0]                                  w_pcie_ingress_rd_size;
wire                                            w_pcie_ingress_rd_stb;
wire    [31:0]                                  w_pcie_ingress_rd_data;
wire                                            w_pcie_ingress_rd_idle;

//Egress FIFO
wire    [1:0]                                   w_pcie_egress_wr_rdy;
wire    [1:0]                                   w_pcie_egress_wr_act;
wire    [23:0]                                  w_pcie_egress_wr_size;
wire                                            w_pcie_egress_wr_stb;
wire    [31:0]                                  w_pcie_egress_wr_data;

//submodules
wire                                            w_mem_write_en;
wire                                            w_mem_read_en;

wire                                            w_per_fifo_sel;
wire                                            w_mem_fifo_sel;
wire                                            w_dma_fifo_sel;

wire    [31:0]                                  w_data_size;
wire    [31:0]                                  w_data_address;
wire                                            w_data_fifo_flg;
wire                                            w_data_read_flg;
wire                                            w_data_write_flg;

wire    [27:0]                                  w_mem_adr;

wire    [1:0]                                   w_ddr3_ingress_rdy;
wire    [23:0]                                  w_ddr3_ingress_size;
wire    [1:0]                                   w_ddr3_ingress_act;
wire                                            w_ddr3_ingress_stb;
wire    [31:0]                                  w_ddr3_ingress_data;

wire                                            w_ddr3_egress_rdy;
wire    [23:0]                                  w_ddr3_egress_size;
wire                                            w_ddr3_egress_act;
wire                                            w_ddr3_egress_stb;
wire    [31:0]                                  w_ddr3_egress_data;
wire                                            w_ddr3_egress_inactive;



artemis_pcie_controller #(
  .DATA_INGRESS_FIFO_DEPTH           (10                           ),
  .DATA_EGRESS_FIFO_DEPTH            (6                            ),
  .SERIAL_NUMBER                     (64'h000000000000C594         )
)api (
  .clk                               (clk                          ), //User Clock
  .rst                               (rst                          ), //User Reset

  //PCIE Phy Interface
  .gtp_clk_p                         (i_pcie_phy_clk_p             ),
  .gtp_clk_n                         (i_pcie_phy_clk_n             ),

  .pci_exp_txp                       (o_pcie_phy_tx_p              ),
  .pci_exp_txn                       (o_pcie_phy_tx_n              ),
  .pci_exp_rxp                       (i_pcie_phy_rx_p              ),
  .pci_exp_rxn                       (i_pcie_phy_rx_n              ),

  // Transaction (TRN) Interface
  .o_pcie_reset                      (o_pcie_reset                 ),
  .user_lnk_up                       (user_lnk_up                  ),
  .clk_62p5                          (clk_62p5                     ),
  .i_pcie_reset                      (i_pcie_reset                 ),

  //User Interfaces
  .o_per_fifo_sel                    (w_per_fifo_sel               ),
  .o_mem_fifo_sel                    (w_mem_fifo_sel               ),
  .o_dma_fifo_sel                    (w_dma_fifo_sel               ),

  .i_write_fin                       (w_write_fin                  ),
  .i_read_fin                        (w_read_fin                   ),

  .i_usr_interrupt_stb               (i_interrupt                  ),
  .i_usr_interrupt_value             (i_usr_interrupt_value        ),

  .o_data_size                       (w_data_size                  ),
  .o_data_address                    (w_data_address               ),
  .o_data_fifo_flg                   (w_data_fifo_flg              ),
  .o_data_read_flg                   (w_data_read_flg              ),
  .o_data_write_flg                  (w_data_write_flg             ),

  //Ingress FIFO
  .i_data_clk                        (clk                          ),
  .o_ingress_fifo_rdy                (w_pcie_ingress_rd_rdy        ),
  .i_ingress_fifo_act                (w_pcie_ingress_rd_act        ),
  .o_ingress_fifo_size               (w_pcie_ingress_rd_size       ),
  .i_ingress_fifo_stb                (w_pcie_ingress_rd_stb        ),
  .o_ingress_fifo_data               (w_pcie_ingress_rd_data       ),
  .o_ingress_fifo_idle               (w_pcie_ingress_rd_idle       ),

  //Egress FIFO
  .o_egress_fifo_rdy                 (w_pcie_egress_wr_rdy         ),
  .i_egress_fifo_act                 (w_pcie_egress_wr_act         ),
  .o_egress_fifo_size                (w_pcie_egress_wr_size        ),
  .i_egress_fifo_stb                 (w_pcie_egress_wr_stb         ),
  .i_egress_fifo_data                (w_pcie_egress_wr_data        ),

  // Configuration: Power Management
  .cfg_turnoff_ok                    (1'b0                         ),
  .cfg_pm_wake                       (1'b0                         ),

  // System Interface
  .received_hot_reset                (received_hot_reset           ),
  .gtp_pll_lock_detect               (gtp_pll_lock_detect          ),
  .gtp_reset_done                    (gtp_reset_done               ),
  .pll_lock_detect                   (pll_lock_detect              ),

  .rx_elec_idle                      (rx_elec_idle                 ),
  .rx_equalizer_ctrl                 (2'b11                        ),

  .tx_diff_ctrl                      (4'h9                         ),
  .tx_pre_emphasis                   (3'b00                        ),

  .o_cfg_read_exec                   (o_cfg_read_exec              ),
  .o_cfg_sm_state                    (o_cfg_sm_state               ),
  .o_sm_state                        (o_sm_state                   ),
  .o_ingress_count                   (o_ingress_count              ),
  .o_ingress_state                   (o_ingress_state              ),
  .o_ingress_ri_count                (o_ingress_ri_count           ),
  .o_ingress_ci_count                (o_ingress_ci_count           ),
  .o_ingress_cmplt_count             (o_ingress_cmplt_count        ),
  .o_ingress_addr                    (o_ingress_addr               ),


  // Configuration: Error
  .cfg_err_ur                        (1'b0                         ),
  .cfg_err_cor                       (1'b0                         ),
  .cfg_err_ecrc                      (1'b0                         ),
  .cfg_err_cpl_timeout               (1'b0                         ),
  .cfg_err_cpl_abort                 (1'b0                         ),
  .cfg_err_posted                    (1'b0                         ),
  .cfg_err_locked                    (1'b0                         ),
  .cfg_err_tlp_cpl_header            (48'b0                        )
  //.cfg_err_cpl_rdy                   (cfg_err_cpl_rdy              )
);

//DDR3 Memory Controller
ddr3_pcie_controller dc (
  .clk                (clk                     ),
  .rst                (rst                     ),

  .data_size          (w_data_size             ),
  .write_address      (w_mem_adr               ),
  .write_en           (w_mem_write_en          ),
  .read_address       (w_mem_adr               ),
  .read_en            (w_mem_read_en           ),
  .finished           (w_mem_fin               ),

  .if_write_strobe    (w_ddr3_ingress_stb      ),
  .if_write_data      (w_ddr3_ingress_data     ),
  .if_write_ready     (w_ddr3_ingress_rdy      ),
  .if_write_activate  (w_ddr3_ingress_act      ),
  .if_write_fifo_size (w_ddr3_ingress_size     ),

  .of_read_strobe     (w_ddr3_egress_stb       ),
  .of_read_ready      (w_ddr3_egress_rdy       ),
  .of_read_activate   (w_ddr3_egress_act       ),
  .of_read_size       (w_ddr3_egress_size      ),
  .of_read_data       (w_ddr3_egress_data      ),
  .of_read_inactive   (w_ddr3_egress_inactive  ),

  .cmd_en             (o_ddr3_cmd_en           ),
  .cmd_instr          (o_ddr3_cmd_instr        ),
  .cmd_bl             (o_ddr3_cmd_bl           ),
  .cmd_word_addr      (o_ddr3_cmd_word_addr    ),
  .cmd_empty          (i_ddr3_cmd_empty        ),
  .cmd_full           (i_ddr3_cmd_full         ),

  .wr_en              (o_ddr3_wr_en            ),
  .wr_mask            (o_ddr3_wr_mask          ),
  .wr_data            (o_ddr3_wr_data          ),
  .wr_full            (i_ddr3_wr_full          ),
  .wr_empty           (i_ddr3_wr_empty         ),
  .wr_count           (i_ddr3_wr_count         ),
  .wr_underrun        (i_ddr3_wr_underrun      ),
  .wr_error           (i_ddr3_wr_error         ),

  .rd_en              (o_ddr3_rd_en            ),
  .rd_data            (i_ddr3_rd_data          ),
  .rd_full            (i_ddr3_rd_full          ),
  .rd_empty           (i_ddr3_rd_empty         ),
  .rd_count           (i_ddr3_rd_count         ),
  .rd_overflow        (i_ddr3_rd_overflow      ),
  .rd_error           (i_ddr3_rd_error         )
);

//Ingress PPFIFO
//Interface to Master

//PPFIFO Multiplexer/Demultiplexer
assign w_per_ingress_rdy     = (w_per_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_rdy :  1'b0;
assign w_per_ingress_size    = (w_per_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_size:  24'h0;
assign w_per_ingress_data    = (w_per_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_data:  32'h0;

assign w_mem_ingress_rdy     = (w_mem_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_rdy :  1'b0;
assign w_mem_ingress_size    = (w_mem_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_size:  24'h0;
assign w_mem_ingress_data    = (w_mem_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_data:  32'h0;

assign o_idma_ready          = (w_dma_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_rdy :  1'b0;
assign o_idma_size           = (w_dma_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_size:  24'h0;
assign o_idma_data           = (w_dma_fifo_sel & w_data_write_flg) ? w_pcie_ingress_rd_data:  32'h0;

assign w_pcie_ingress_rd_act = (w_per_fifo_sel & w_data_write_flg) ? w_per_ingress_act :
                               (w_mem_fifo_sel & w_data_write_flg) ? w_mem_ingress_act :
                               (w_dma_fifo_sel & w_data_write_flg) ? i_idma_activate :
                               1'b0;
assign w_pcie_ingress_rd_stb = (w_per_fifo_sel & w_data_write_flg) ? w_per_ingress_stb :
                               (w_mem_fifo_sel & w_data_write_flg) ? w_mem_ingress_stb :
                               (w_dma_fifo_sel & w_data_write_flg) ? i_idma_stb :
                               1'b0;

//Egress FIFO
assign w_per_egress_rdy      = (w_per_fifo_sel & w_data_read_flg) ? w_pcie_egress_wr_rdy :  2'b0;
assign w_mem_egress_rdy      = (w_mem_fifo_sel & w_data_read_flg) ? w_pcie_egress_wr_rdy :  2'b0;
assign o_odma_ready          = (w_dma_fifo_sel & w_data_read_flg) ? w_pcie_egress_wr_rdy :  2'b0;

assign w_per_egress_size     = (w_per_fifo_sel & w_data_read_flg) ? w_pcie_egress_wr_size:  24'h0;
assign w_mem_egress_size     = (w_mem_fifo_sel & w_data_read_flg) ? w_pcie_egress_wr_size:  24'h0;
assign o_odma_size           = (w_dma_fifo_sel & w_data_read_flg) ? w_pcie_egress_wr_size:  24'h0;

assign w_pcie_egress_wr_act  = (w_per_fifo_sel & w_data_read_flg) ? w_per_egress_act  :
                               (w_mem_fifo_sel & w_data_read_flg) ? w_mem_egress_act  :
                               (w_dma_fifo_sel & w_data_read_flg) ? i_odma_activate   :
                               1'b0;
assign w_pcie_egress_wr_data = (w_per_fifo_sel & w_data_read_flg) ? w_per_egress_data :
                               (w_mem_fifo_sel & w_data_read_flg) ? w_mem_egress_data :
                               (w_dma_fifo_sel & w_data_read_flg) ? i_odma_data       :
                               1'b0;
assign w_pcie_egress_wr_stb  = (w_per_fifo_sel & w_data_read_flg) ? w_per_egress_stb  :
                               (w_mem_fifo_sel & w_data_read_flg) ? w_mem_egress_stb  :
                               (w_dma_fifo_sel & w_data_read_flg) ? i_odma_stb        :
                               1'b0;

assign w_mem_adr             = w_data_address[27:0];
assign w_mem_write_en        = w_data_write_flg & w_mem_fifo_sel;
assign w_mem_read_en         = w_data_read_flg  & w_mem_fifo_sel;


assign w_write_fin            = (w_per_fifo_sel & w_data_write_flg) ? w_ing_per_fin   :
                                (w_mem_fifo_sel & w_data_write_flg) ? w_mem_fin       :
                                (w_dma_fifo_sel & w_data_write_flg) ? w_dma_write_fin :
                                1'b0;

assign w_read_fin             = (w_per_fifo_sel & w_data_read_flg)  ? w_egr_per_fin   :
                                (w_mem_fifo_sel & w_data_read_flg)  ? (w_mem_fin  & w_ddr3_egress_inactive):
                                (w_dma_fifo_sel & w_data_read_flg)  ? r_dma_read_fin  :
                                1'b0;


//assign w_per_fin              = w_ing_per_fin | w_egr_per_fin;
assign w_dma_write_fin        = w_pcie_ingress_rd_idle;

assign  o_per_fifo_sel        = w_per_fifo_sel;
assign  o_mem_fifo_sel        = w_mem_fifo_sel;
assign  o_dma_fifo_sel        = w_dma_fifo_sel;

assign  o_write_flag          = w_data_write_flg;
assign  o_read_flag           = w_data_read_flg;


assign o_debug_data[0]      = w_data_read_flg;
assign o_debug_data[1]      = w_data_write_flg;
assign o_debug_data[2]      = w_dma_fifo_sel;
assign o_debug_data[3]      = i_oh_en;
assign o_debug_data[4]      = w_per_fifo_sel;
assign o_debug_data[5]      = w_ing_per_fin;
assign o_debug_data[6]      = w_write_fin;
assign o_debug_data[7]      = w_per_egress_stb;
assign o_debug_data[11:8]   = o_sm_state;
assign o_debug_data[15:12]  = o_oh_state;
assign o_debug_data[17:16]  = w_per_egress_act;
//assign o_debug_data[5]      = w_pcie_ingress_rd_stb;
//assign o_debug_data[6]      = w_pcie_ingress_rd_act;
//assign o_debug_data[7]      = w_pcie_ingress_rd_rdy;
//assign o_debug_data[8]      = w_pcie_egress_wr_stb;
//assign o_debug_data[10:9]   = w_pcie_egress_wr_act;
//assign o_debug_data[12:11]  = w_pcie_egress_wr_rdy;
//assign o_debug_data[13]     = w_per_egress_stb;
//assign o_debug_data[15:14]  = w_per_egress_act;
//assign o_debug_data[17:16]  = w_per_egress_rdy;
assign o_debug_data[18]     = w_per_ingress_stb;
assign o_debug_data[19]     = w_per_ingress_act;
assign o_debug_data[20]     = w_per_ingress_rdy;
assign o_debug_data[24:21]  = o_ih_state;
assign o_debug_data[26:25]  = o_in_command;
assign o_debug_data[30:27]  = o_in_data;
assign o_debug_data[31]     = w_egr_per_fin;


reg   [31:0]                  r_dma_count;
always @ (posedge clk) begin
  if (rst) begin
    r_dma_count               <=  0;
    r_dma_read_fin            <=  0;
  end
  else begin
    if (w_data_read_flg & w_dma_fifo_sel) begin
      if (r_dma_count < w_data_size) begin
        if (i_odma_stb) begin
          r_dma_count           <=  r_dma_count + 1;
        end
      end
      else begin
        r_dma_read_fin          <=  1;
      end
    end
    else begin
      r_dma_count               <=  0;
      r_dma_read_fin            <=  0;
    end
  end
end

ppfifo_pcie_host_interface phi (
  //boilerplate
  .rst                (rst              ),
  .clk                (clk              ),

  .i_ing_en           (w_per_fifo_sel & w_data_write_flg  ),
  .i_egr_en           (w_per_fifo_sel & w_data_read_flg   ),

  .o_ing_fin          (w_ing_per_fin    ),
  .o_egr_fin          (w_egr_per_fin    ),

  //master interface
  .i_master_ready     (i_master_ready   ),
  .o_ih_reset         (o_ih_reset       ),
  .o_ih_ready         (o_ih_ready       ),

  .o_in_command       (o_in_command     ),
  .o_in_address       (o_in_address     ),
  .o_in_data          (o_in_data        ),
  .o_in_data_count    (o_in_data_count  ),

  .o_oh_ready         (o_oh_ready       ),
  .i_oh_en            (i_oh_en          ),

  .o_ih_state         (o_ih_state       ),
  .o_oh_state         (o_oh_state       ),

  .i_out_status       (i_out_status     ),
  .i_out_address      (i_out_address    ),
  .i_out_data         (i_out_data       ),
  .i_out_data_count   (i_out_data_count ),

  .o_id_value         (o_id_value           ),
  .o_command_value    (o_command_value      ),
  .o_count_value      (o_count_value        ),
  .o_address_value    (o_address_value      ),

  //Ingress Ping Pong
  .i_ingress_rdy      (w_per_ingress_rdy    ),
  .o_ingress_act      (w_per_ingress_act    ),
  .o_ingress_stb      (w_per_ingress_stb    ),
  .i_ingress_size     (w_per_ingress_size   ),
  .i_ingress_data     (w_per_ingress_data   ),

  //Egress Ping Pong
  .i_egress_rdy       (w_per_egress_rdy     ),
  .o_egress_act       (w_per_egress_act     ),
  .o_egress_stb       (w_per_egress_stb     ),
  .i_egress_size      (w_per_egress_size    ),
  .o_egress_data      (w_per_egress_data    )
);

//Memory FIFO Adapter
adapter_ppfifo_2_ppfifo ap2p_to_ddr3 (
  .clk                (clk                ),
  .rst                (rst                ),

  .i_read_ready       (w_mem_ingress_rdy  ),
  .o_read_activate    (w_mem_ingress_act  ),
  .i_read_size        (w_mem_ingress_size ),
  .i_read_data        (w_mem_ingress_data ),
  .o_read_stb         (w_mem_ingress_stb  ),

  .i_write_ready      (w_ddr3_ingress_rdy ),
  .o_write_activate   (w_ddr3_ingress_act ),
  .i_write_size       (w_ddr3_ingress_size),
  .o_write_stb        (w_ddr3_ingress_stb ),
  .o_write_data       (w_ddr3_ingress_data)
);

adapter_ppfifo_2_ppfifo ap2p_from_ddr3 (
  .clk                (clk                ),
  .rst                (rst                ),

  .i_read_ready       (w_ddr3_egress_rdy  ),
  .o_read_activate    (w_ddr3_egress_act  ),
  .i_read_size        (w_ddr3_egress_size ),
  .i_read_data        (w_ddr3_egress_data ),
  .o_read_stb         (w_ddr3_egress_stb  ),

  .i_write_ready      (w_mem_egress_rdy   ),
  .o_write_activate   (w_mem_egress_act   ),
  .i_write_size       (w_mem_egress_size  ),
  .o_write_stb        (w_mem_egress_stb   ),
  .o_write_data       (w_mem_egress_data  )
);

//Asynchronous Logic
assign  o_ddr3_cmd_clk              = clk;
assign  o_ddr3_wr_clk               = clk;
assign  o_ddr3_rd_clk               = clk;
assign  o_ddr3_cmd_byte_addr        = {o_ddr3_cmd_word_addr, 2'b0};


assign  o_pcie_wake_n               = 1'b1;
//Synchronous Logic



endmodule
