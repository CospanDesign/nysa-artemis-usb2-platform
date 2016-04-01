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
`include "project_defines.v"

module artemis_pcie_interface #(
  parameter CONTROL_FIFO_DEPTH        = 7,
  parameter DATA_FIFO_DEPTH           = 9,
  parameter SERIAL_NUMBER             = 64'h000000000000C594
)(
  input                     clk,
  input                     rst,

  //The Following Signals are clocked at 62.5MHz

  // PCI Express Fabric Interface
  input                     gtp_clk_p,
  input                     gtp_clk_n,

  output                    pci_exp_txp,
  output                    pci_exp_txn,
  input                     pci_exp_rxp,
  input                     pci_exp_rxn,

  input                     read_bar_addr_stb,

  // Transaction (TRN) Interface
  output                    user_lnk_up,
  output                    clk_62p5,


  // Flow Control
  input       [2:0]         fc_sel,
  output      [7:0]         fc_nph,
  output      [11:0]        fc_npd,
  output      [7:0]         fc_ph,
  output      [11:0]        fc_pd,
  output      [7:0]         fc_cplh,
  output      [11:0]        fc_cpld,

  // Host (CFG) Interface
  //output      [31:0]        cfg_do,
  //output                    cfg_rd_wr_done,
  //input       [9:0]         cfg_dwaddr,
  //input                     cfg_rd_en,

  // Configuration: Error
  input                     cfg_err_ur,
  input                     cfg_err_cor,
  input                     cfg_err_ecrc,
  input                     cfg_err_cpl_timeout,
  input                     cfg_err_cpl_abort,
  input                     cfg_err_posted,
  input                     cfg_err_locked,
  input       [47:0]        cfg_err_tlp_cpl_header,
  output                    cfg_err_cpl_rdy,

  // Conifguration: Interrupt
/*
  input                     cfg_interrupt,
  output                    cfg_interrupt_rdy,
  input                     cfg_interrupt_assert,
  output      [7:0]         cfg_interrupt_do,
  input       [7:0]         cfg_interrupt_di,
  output      [2:0]         cfg_interrupt_mmenable,
  output                    cfg_interrupt_msienable,
*/


  input                     i_interrupt_stb,
  input       [7:0]         i_interrupt_channel,

  // Configuration: Power Management
  input                     cfg_turnoff_ok,
  output                    cfg_to_turnoff,
  input                     cfg_pm_wake,

  // Configuration: System/Status
  output      [2:0]         cfg_pcie_link_state,
  input                     cfg_trn_pending_stb,
  output      [7:0]         cfg_bus_number,
  output      [4:0]         cfg_device_number,
  output      [2:0]         cfg_function_number,

  output      [15:0]        cfg_status,
  output      [15:0]        cfg_command,
  output      [15:0]        cfg_dstatus,
  output      [15:0]        cfg_dcommand,
  output      [15:0]        cfg_lstatus,
  output      [15:0]        cfg_lcommand,

  // System Interface
  output                    pcie_reset,
  output                    pll_lock_detect,
  output                    gtp_pll_lock_detect,
  output                    gtp_reset_done,
  output                    rx_elec_idle,
  output                    received_hot_reset,

  input                     i_cmd_in_rd_stb,
  output                    o_cmd_in_rd_ready,
  input                     i_cmd_in_rd_activate,
  output      [23:0]        o_cmd_in_rd_count,
  output      [31:0]        o_cmd_in_rd_data,

  output      [1:0]         o_cmd_out_wr_ready,
  input       [1:0]         i_cmd_out_wr_activate,
  output      [23:0]        o_cmd_out_wr_size,
  input                     i_cmd_out_wr_stb,
  input       [31:0]        i_cmd_out_wr_data,

  input                     i_data_in_rd_stb,
  output                    o_data_in_rd_ready,
  input                     i_data_in_rd_activate,
  output      [23:0]        o_data_in_rd_count,
  output      [31:0]        o_data_in_rd_data,

  output      [1:0]         o_data_out_wr_ready,
  input       [1:0]         i_data_out_wr_activate,
  output      [23:0]        o_data_out_wr_size,
  input                     i_data_out_wr_stb,
  input       [31:0]        i_data_out_wr_data,

  output      [31:0]        o_bar_addr0,
  output      [31:0]        o_bar_addr1,
  output      [31:0]        o_bar_addr2,
  output      [31:0]        o_bar_addr3,
  output      [31:0]        o_bar_addr4,
  output      [31:0]        o_bar_addr5,

//  output      [6:0]         rx_bar_hit,
  output                    rx_rcv_data_valid,

  input       [1:0]         rx_equalizer_ctrl,
  input       [3:0]         tx_diff_ctrl,
  input       [2:0]         tx_pre_emphasis,
  output      [4:0]         cfg_ltssm_state,

  output      [6:0]         o_bar_hit,
  output                    o_receive_axi_ready,



  output                    dbg_reg_detected_correctable,
  output                    dbg_reg_detected_fatal,
  output                    dbg_reg_detected_non_fatal,
  output                    dbg_reg_detected_unsupported,

  output                    dbg_bad_dllp_status,
  output                    dbg_bad_tlp_lcrc,
  output                    dbg_bad_tlp_seq_num,
  output                    dbg_bad_tlp_status,
  output                    dbg_dl_protocol_status,
  output                    dbg_fc_protocol_err_status,
  output                    dbg_mlfrmd_length,
  output                    dbg_mlfrmd_mps,
  output                    dbg_mlfrmd_tcvc,
  output                    dbg_mlfrmd_tlp_status,
  output                    dbg_mlfrmd_unrec_type,
  output                    dbg_poistlpstatus,
  output                    dbg_rcvr_overflow_status,
  output                    dbg_rply_rollover_status,
  output                    dbg_rply_timeout_status,
  output                    dbg_ur_no_bar_hit,
  output                    dbg_ur_pois_cfg_wr,
  output                    dbg_ur_status,
  output                    dbg_ur_unsup_msg
);

//local parameters
localparam      CONTROL_FIFO_SIZE     = (2 ** CONTROL_FIFO_DEPTH);
localparam      DATA_FIFO_SIZE        = (2 ** DATA_FIFO_DEPTH);


localparam      CONTROL_SELECT   = 0;
localparam      DATA_SELECT      = 1;
localparam      DMA_SELECT       = 2;
//registes/wires


(* KEEP = "TRUE" *) wire    clk_62p5;


//Control Signals
wire  [1:0]                 c_in_wr_ready;
wire  [1:0]                 c_in_wr_activate;
wire  [23:0]                c_in_wr_size;
wire                        c_in_wr_stb;
wire  [31:0]                c_in_wr_data;

wire                        c_out_rd_stb;
wire                        c_out_rd_ready;
wire                        c_out_rd_activate;
wire  [23:0]                c_out_rd_size;
wire  [31:0]                c_out_rd_data;

//Data
wire  [1:0]                 d_in_wr_ready;
wire  [1:0]                 d_in_wr_activate;
wire  [23:0]                d_in_wr_size;
wire                        d_in_wr_stb;
wire  [31:0]                d_in_wr_data;

wire                        d_out_rd_stb;
wire                        d_out_rd_ready;
wire                        d_out_rd_activate;
wire  [23:0]                d_out_rd_size;
wire  [31:0]                d_out_rd_data;

//Control Signals
wire                        c_in_axi_ready;
wire          [31:0]        c_in_axi_data;
wire          [3:0]         c_in_axi_keep;
wire                        c_in_axi_last;
wire                        c_in_axi_valid;

wire                        c_out_axi_ready;
wire          [31:0]        c_out_axi_data;
wire          [3:0]         c_out_axi_keep;
wire                        c_out_axi_last;
wire                        c_out_axi_valid;


//Data Signals
wire                        d_in_axi_ready;
wire          [31:0]        d_in_axi_data;
wire          [3:0]         d_in_axi_keep;
wire                        d_in_axi_last;
wire                        d_in_axi_valid;

wire                        d_out_axi_ready;
wire          [31:0]        d_out_axi_data;
wire          [3:0]         d_out_axi_keep;
wire                        d_out_axi_last;
wire                        d_out_axi_valid;

//Control Signals
wire                        dma_in_axi_ready;
wire          [31:0]        dma_in_axi_data;
wire          [3:0]         dma_in_axi_keep;
wire                        dma_in_axi_last;
wire                        dma_in_axi_valid;

wire                        dma_out_axi_ready;
wire          [31:0]        dma_out_axi_data;
wire          [3:0]         dma_out_axi_keep;
wire                        dma_out_axi_last;
wire                        dma_out_axi_valid;



wire          [31:0]        m_axis_rx_tdata;
wire          [3:0]         m_axis_rx_tkeep;
wire                        m_axis_rx_tlast;
wire                        m_axis_rx_tvalid;
wire                        m_axis_rx_tready;
wire          [21:0]        m_axis_rx_tuser;

wire                        s_axis_tx_tready;
wire          [31:0]        s_axis_tx_tdata;
wire          [3:0]         s_axis_tx_tkeep;
wire          [3:0]         s_axis_tx_tuser;
wire                        s_axis_tx_tlast;
wire                        s_axis_tx_tvalid;

wire                        cfg_trn_pending;
//assign                      s_axis_tx_tuser = 0;

reg                         cfg_interrupt;
wire                        cfg_interrupt_rdy;
wire                        cfg_interrupt_assert;
wire          [7:0]         cfg_interrupt_do;
wire          [7:0]         cfg_interrupt_di;
wire          [2:0]         cfg_interrupt_mmenable;
wire                        cfg_interrupt_msienable;




wire                        s_axis_tx_discont;
wire                        s_axis_tx_stream;
wire                        s_axis_tx_err_fwd;
wire                        s_axis_tx_s6_not_used;

wire          [31:0]        cfg_do;
wire                        cfg_rd_wr_done;
wire          [9:0]         cfg_dwaddr;
wire                        cfg_rd_en;

wire                        cfg_enable;

wire                        tx_cfg_gnt;
wire                        rx_np_ok;
wire  [6:0]                 w_bar_hit;



assign  s_axis_tx_discont     = 0;
assign  s_axis_tx_stream      = 0;
assign  s_axis_tx_err_fwd     = 0;
assign  s_axis_tx_s6_not_used = 0;

assign  s_axis_tx_tuser       = {s_axis_tx_discont,
                                 s_axis_tx_stream,
                                 s_axis_tx_err_fwd,
                                 s_axis_tx_s6_not_used};

assign  o_bar_hit             = m_axis_rx_tuser[8:2];

assign  cfg_trn_pending       =  1'b0;
assign  tx_cfg_gnt            =  1'b1;
assign  rx_np_ok              =  1'b1;

//pcie_axi_bridge pcie_interface
sim_pcie_axi_bridge pcie_interface
(

  // PCI Express Fabric Interface
  .pci_exp_txp                       (pci_exp_txp             ),
  .pci_exp_txn                       (pci_exp_txn             ),
  .pci_exp_rxp                       (pci_exp_rxp             ),
  .pci_exp_rxn                       (pci_exp_rxn             ),

  // Transaction (TRN) Interface
  .user_lnk_up                       (user_lnk_up             ),

  // Tx
  .s_axis_tx_tready                  (s_axis_tx_tready        ),
  .s_axis_tx_tdata                   (s_axis_tx_tdata         ),
  .s_axis_tx_tkeep                   (s_axis_tx_tkeep         ),
  .s_axis_tx_tuser                   (s_axis_tx_tuser         ),
  .s_axis_tx_tlast                   (s_axis_tx_tlast         ),
  .s_axis_tx_tvalid                  (s_axis_tx_tvalid        ),

/*
//TODO
  output  reg [5:0]   tx_buf_av,
  output  reg         tx_err_drop,
  output  reg         tx_cfg_req,
*/
  .tx_cfg_gnt                        (tx_cfg_gnt               ),
  .user_enable_comm                  (user_enable_comm         ),


  // Rx
  .m_axis_rx_tdata                   (m_axis_rx_tdata         ),
  .m_axis_rx_tkeep                   (m_axis_rx_tkeep         ),
  .m_axis_rx_tlast                   (m_axis_rx_tlast         ),
  .m_axis_rx_tvalid                  (m_axis_rx_tvalid        ),
  .m_axis_rx_tready                  (m_axis_rx_tready        ),
  .m_axis_rx_tuser                   (m_axis_rx_tuser         ),
//  output  reg [21:0]  m_axis_rx_tuser,
//  input               rx_np_ok,
  .rx_np_ok                          (rx_np_ok                ),

  // Flow Control
  .fc_sel                            (fc_sel                  ),
  .fc_nph                            (fc_nph                  ),
  .fc_npd                            (fc_npd                  ),
  .fc_ph                             (fc_ph                   ),
  .fc_pd                             (fc_pd                   ),
  .fc_cplh                           (fc_cplh                 ),
  .fc_cpld                           (fc_cpld                 ),

  // Host Interface
  .cfg_do                            (cfg_do                  ),
  .cfg_rd_wr_done                    (cfg_rd_wr_done          ),
  .cfg_dwaddr                        (cfg_dwaddr              ),
  .cfg_rd_en                         (cfg_rd_en               ),

  // Configuration: Error
  .cfg_err_ur                        (cfg_err_ur              ),
  .cfg_err_cor                       (cfg_err_cor             ),
  .cfg_err_ecrc                      (cfg_err_ecrc            ),
  .cfg_err_cpl_timeout               (cfg_err_cpl_timeout     ),
  .cfg_err_cpl_abort                 (cfg_err_cpl_abort       ),
  .cfg_err_posted                    (cfg_err_posted          ),
  .cfg_err_locked                    (cfg_err_locked          ),
  .cfg_err_tlp_cpl_header            (cfg_err_tlp_cpl_header  ),
  .cfg_err_cpl_rdy                   (cfg_err_cpl_rdy         ),

  // Conifguration: Interrupt
  .cfg_interrupt                     (cfg_interrupt           ),
  .cfg_interrupt_rdy                 (cfg_interrupt_rdy       ),
  .cfg_interrupt_assert              (cfg_interrupt_assert    ),
  .cfg_interrupt_do                  (cfg_interrupt_do        ),
  .cfg_interrupt_di                  (cfg_interrupt_di        ),
  .cfg_interrupt_mmenable            (cfg_interrupt_mmenable  ),
  .cfg_interrupt_msienable           (cfg_interrupt_msienable ),

  // Configuration: Power Management
  .cfg_turnoff_ok                    (cfg_turnoff_ok          ),
  .cfg_to_turnoff                    (cfg_to_turnoff          ),
  .cfg_pm_wake                       (cfg_pm_wake             ),

  //Core Controller

  // Configuration: System/Status
  .cfg_pcie_link_state               (cfg_pcie_link_state     ),
  .cfg_trn_pending                   (cfg_trn_pending         ),
  .cfg_dsn                           (SERIAL_NUMBER           ),
  .cfg_bus_number                    (cfg_bus_number          ),
  .cfg_device_number                 (cfg_device_number       ),
  .cfg_function_number               (cfg_function_number     ),

  .cfg_status                        (cfg_status              ),
  .cfg_command                       (cfg_command             ),
  .cfg_dstatus                       (cfg_dstatus             ),
  .cfg_dcommand                      (cfg_dcommand            ),
  .cfg_lstatus                       (cfg_lstatus             ),
  .cfg_lcommand                      (cfg_lcommand            ),

  // System Interface
  .sys_clk_p                         (gtp_clk_p               ),
  .sys_clk_n                         (gtp_clk_n               ),
  .sys_reset                         (rst                     ),
  .user_clk_out                      (clk_62p5                ),
  .user_reset_out                    (pcie_reset              ),
  .received_hot_reset                (received_hot_reset      ),

  .pll_lock_detect                   (pll_lock_detect         ),
  .gtp_pll_lock_detect               (gtp_pll_lock_detect     ),
  .gtp_reset_done                    (gtp_reset_done          ),
  .rx_elec_idle                      (rx_elec_idle            ),

  .rx_equalizer_ctrl                 (rx_equalizer_ctrl       ),
  .tx_diff_ctrl                      (tx_diff_ctrl            ),
  .tx_pre_emphasis                   (tx_pre_emphasis         ),
  .cfg_ltssm_state                   (cfg_ltssm_state         ),

  .o_bar_hit                         (w_bar_hit                     ),
  .dbg_reg_detected_correctable      (dbg_reg_detected_correctable  ),
  .dbg_reg_detected_fatal            (dbg_reg_detected_fatal        ),
  .dbg_reg_detected_non_fatal        (dbg_reg_detected_non_fatal    ),
  .dbg_reg_detected_unsupported      (dbg_reg_detected_unsupported  ),

  .dbg_bad_dllp_status               (dbg_bad_dllp_status        ),
  .dbg_bad_tlp_lcrc                  (dbg_bad_tlp_lcrc           ),
  .dbg_bad_tlp_seq_num               (dbg_bad_tlp_seq_num        ),
  .dbg_bad_tlp_status                (dbg_bad_tlp_status         ),
  .dbg_dl_protocol_status            (dbg_dl_protocol_status     ),
  .dbg_fc_protocol_err_status        (dbg_fc_protocol_err_status ),
  .dbg_mlfrmd_length                 (dbg_mlfrmd_length          ),
  .dbg_mlfrmd_mps                    (dbg_mlfrmd_mps             ),
  .dbg_mlfrmd_tcvc                   (dbg_mlfrmd_tcvc            ),
  .dbg_mlfrmd_tlp_status             (dbg_mlfrmd_tlp_status      ),
  .dbg_mlfrmd_unrec_type             (dbg_mlfrmd_unrec_type      ),
  .dbg_poistlpstatus                 (dbg_poistlpstatus          ),
  .dbg_rcvr_overflow_status          (dbg_rcvr_overflow_status   ),
  .dbg_rply_rollover_status          (dbg_rply_rollover_status   ),
  .dbg_rply_timeout_status           (dbg_rply_timeout_status    ),
  .dbg_ur_no_bar_hit                 (dbg_ur_no_bar_hit          ),
  .dbg_ur_pois_cfg_wr                (dbg_ur_pois_cfg_wr         ),
  .dbg_ur_status                     (dbg_ur_status              ),
  .dbg_ur_unsup_msg                  (dbg_ur_unsup_msg           )
);


config_parser cfg (
  .rst              (pcie_reset           ),
  .clk              (clk_62p5             ),

  .i_en             (cfg_enable           ),

  .i_cfg_do         (cfg_do               ),
  .i_cfg_rd_wr_done (cfg_rd_wr_done       ),
  .o_cfg_dwaddr     (cfg_dwaddr           ),
  .o_cfg_rd_en      (cfg_rd_en            ),


  .o_bar_addr0      (o_bar_addr0          ),
  .o_bar_addr1      (o_bar_addr1          ),
  .o_bar_addr2      (o_bar_addr2          ),
  .o_bar_addr3      (o_bar_addr3          ),
  .o_bar_addr4      (o_bar_addr4          ),
  .o_bar_addr5      (o_bar_addr5          )
);

adapter_axi_stream_2_ppfifo cntrl_a2p (
  .rst              (pcie_reset           ),

  //AXI Stream Input
  .i_axi_clk        (clk_62p5             ),
  .o_axi_ready      (c_in_axi_ready       ),
  .i_axi_data       (c_in_axi_data        ),
  .i_axi_keep       (c_in_axi_keep        ),
  .i_axi_last       (c_in_axi_last        ),
  .i_axi_valid      (c_in_axi_valid       ),

  //Ping Pong FIFO Write Controller
  //.o_ppfifo_clk     (clk_62p5             ),
  .o_ppfifo_clk     (                     ),
  .i_ppfifo_rdy     (c_in_wr_ready        ),
  .o_ppfifo_act     (c_in_wr_activate     ),
  .i_ppfifo_size    (c_in_wr_size         ),
  .o_ppfifo_stb     (c_in_wr_stb          ),
  .o_ppfifo_data    (c_in_wr_data         )
);

ppfifo #(
  .DATA_WIDTH       (32                   ),
  .ADDRESS_WIDTH    (CONTROL_FIFO_DEPTH - 2)
) pcie_control_ingress (

  //Control Signals
  .reset            (pcie_reset           ),

  //Write Side
  .write_clock      (clk_62p5             ),
  .write_ready      (c_in_wr_ready        ),
  .write_activate   (c_in_wr_activate     ),
  .write_fifo_size  (c_in_wr_size         ),
  .write_strobe     (c_in_wr_stb          ),
  .write_data       (c_in_wr_data         ),
  .starved          (                     ),

  //Read Size
  .read_clock       (clk                  ),
  .read_strobe      (i_cmd_in_rd_stb      ),
  .read_ready       (o_cmd_in_rd_ready    ),
  .read_activate    (i_cmd_in_rd_activate ),
  .read_count       (o_cmd_in_rd_count    ),
  .read_data        (o_cmd_in_rd_data     ),
  .inactive         (                     )
);

ppfifo #(
  .DATA_WIDTH       (32                   ),
  .ADDRESS_WIDTH    (CONTROL_FIFO_DEPTH - 2)
) pcie_control_egress (

  //Control Signals
  .reset            (pcie_reset           ),

  //Write Side
  .write_clock      (clk                  ),
  .write_ready      (o_cmd_out_wr_ready   ),
  .write_activate   (i_cmd_out_wr_activate),
  .write_fifo_size  (o_cmd_out_wr_size    ),
  .write_strobe     (i_cmd_out_wr_stb     ),
  .write_data       (i_cmd_out_wr_data    ),
  .starved          (                     ),

  //Read Size
  .read_clock       (clk_62p5             ),
  .read_strobe      (c_out_rd_stb         ),
  .read_ready       (c_out_rd_ready       ),
  .read_activate    (c_out_rd_activate    ),
  .read_count       (c_out_rd_size        ),
  .read_data        (c_out_rd_data        ),
  .inactive         (                     )
);


adapter_ppfifo_2_axi_stream control_p2a (
  .rst              (pcie_reset           ),

  //Ping Poing FIFO Read Interface
  .i_ppfifo_clk     (clk_62p5             ),
  .i_ppfifo_rdy     (c_out_rd_ready       ),
  .o_ppfifo_act     (c_out_rd_activate    ),
  .i_ppfifo_size    (c_out_rd_size        ),
  .i_ppfifo_data    (c_out_rd_data        ),
  .o_ppfifo_stb     (c_out_rd_stb         ),

  //AXI Stream Output (clock read from i_ppfifo_clk)
  .o_axi_clk        (                     ),
  .i_axi_ready      (c_out_axi_ready      ),
  .o_axi_data       (c_out_axi_data       ),
  .o_axi_keep       (c_out_axi_keep       ),
  .o_axi_last       (c_out_axi_last       ),
  .o_axi_valid      (c_out_axi_valid      )

);

//Data FIFOs
adapter_axi_stream_2_ppfifo data_a2p (
  .rst              (pcie_reset           ),

  //AXI Stream Input
  .i_axi_clk        (clk_62p5             ),
  .o_axi_ready      (d_in_axi_ready       ),
  .i_axi_data       (d_in_axi_data        ),
  .i_axi_keep       (d_in_axi_keep        ),
  .i_axi_last       (d_in_axi_last        ),
  .i_axi_valid      (d_in_axi_valid       ),

  //AXI Stream Output (clock read from i_ppfifo_clk)
  //Ping Pong FIFO Write Controller
  .o_ppfifo_clk     (                     ),
  .i_ppfifo_rdy     (d_in_wr_ready        ),
  .o_ppfifo_act     (d_in_wr_activate     ),
  .i_ppfifo_size    (d_in_wr_size         ),
  .o_ppfifo_stb     (d_in_wr_stb          ),
  .o_ppfifo_data    (d_in_wr_data         )
);

ppfifo #(
  .DATA_WIDTH       (32                   ),
  .ADDRESS_WIDTH    (DATA_FIFO_DEPTH - 2  )
) pcie_data_ingress (

  //Control Signals
  .reset            (pcie_reset           ),

  //Write Side
  .write_clock      (clk_62p5             ),
  .write_ready      (d_in_wr_ready        ),
  .write_activate   (d_in_wr_activate     ),
  .write_fifo_size  (d_in_wr_size         ),
  .write_strobe     (d_in_wr_stb          ),
  .write_data       (d_in_wr_data         ),
  .starved          (                     ),

  //Read Size
  .read_clock       (clk                  ),
  .read_strobe      (i_data_in_rd_stb     ),
  .read_ready       (o_data_in_rd_ready   ),
  .read_activate    (i_data_in_rd_activate),
  .read_count       (o_data_in_rd_count   ),
  .read_data        (o_data_in_rd_data    ),
  .inactive         (                     )
);


ppfifo #(
  .DATA_WIDTH       (32                   ),
  .ADDRESS_WIDTH    (DATA_FIFO_DEPTH - 2  )
) pcie_data_egress (

  //Control Signals
  .reset            (pcie_reset           ),

  //Write Side
  .write_clock      (clk                  ),
  .write_ready      (o_data_out_wr_ready  ),
  .write_activate   (i_data_out_wr_activate),
  .write_fifo_size  (o_data_out_wr_size   ),
  .write_strobe     (i_data_out_wr_stb    ),
  .write_data       (i_data_out_wr_data   ),
  .starved          (),

  //Read Size
  .read_clock       (clk_62p5             ),
  .read_strobe      (d_out_rd_stb         ),
  .read_ready       (d_out_rd_ready       ),
  .read_activate    (d_out_rd_activate    ),
  .read_count       (d_out_rd_size        ),
  .read_data        (d_out_rd_data        ),
  .inactive         (                     )
);

adapter_ppfifo_2_axi_stream data_p2a (
  .rst              (pcie_reset           ),

  //Ping Poing FIFO Read Interface
  .i_ppfifo_clk     (clk_62p5             ),
  .i_ppfifo_rdy     (d_out_rd_ready       ),
  .o_ppfifo_act     (d_out_rd_activate    ),
  .i_ppfifo_size    (d_out_rd_size        ),
  .i_ppfifo_data    (d_out_rd_data        ),
  .o_ppfifo_stb     (d_out_rd_stb         ),

  //AXI Stream Output
  .o_axi_clk        (                     ),
  .i_axi_ready      (d_out_axi_ready      ),
  .o_axi_data       (d_out_axi_data       ),
  .o_axi_keep       (d_out_axi_keep       ),
  .o_axi_last       (d_out_axi_last       ),
  .o_axi_valid      (d_out_axi_valid      )
);

//asynchronous logic

assign  o_receive_axi_ready     = m_axis_rx_tready;

//Map the PCIE to PPFIFO FIFO

assign  c_in_axi_data     = m_axis_rx_tdata;
assign  d_in_axi_data     = m_axis_rx_tdata;
assign  dma_in_axi_data   = m_axis_rx_tdata;

assign  c_in_axi_keep     = m_axis_rx_tkeep;
assign  d_in_axi_keep     = m_axis_rx_tkeep;
assign  dma_in_axi_keep   = m_axis_rx_tkeep;

assign  c_in_axi_last     = m_axis_rx_tlast;
assign  d_in_axi_last     = m_axis_rx_tlast;
assign  dma_in_axi_last   = m_axis_rx_tlast;

assign  c_in_axi_valid    = o_bar_hit[CONTROL_SELECT] ? m_axis_rx_tvalid: 1'b0;
assign  d_in_axi_valid    = o_bar_hit[DATA_SELECT]    ? m_axis_rx_tvalid: 1'b0;
assign  dma_in_axi_valid  = o_bar_hit[DMA_SELECT]     ? m_axis_rx_tvalid: 1'b0;

assign  c_out_axi_ready   = o_bar_hit[CONTROL_SELECT] ? s_axis_tx_tready: 1'b0;
assign  d_out_axi_ready   = o_bar_hit[DATA_SELECT]    ? s_axis_tx_tready: 1'b0;
assign  dma_in_axi_ready  = o_bar_hit[DMA_SELECT]     ? m_axis_rx_tready: 1'b0;

//Many to one
assign  m_axis_rx_tready  = o_bar_hit[CONTROL_SELECT] ? c_in_axi_ready  :
                            o_bar_hit[DATA_SELECT]    ? d_in_axi_ready  :
                            o_bar_hit[DMA_SELECT]     ? dma_in_axi_ready:
                            1'b0;

//Transmit Data (Many to one)
assign  s_axis_tx_tdata   = o_bar_hit[CONTROL_SELECT] ? c_out_axi_data  :
                            o_bar_hit[DATA_SELECT]    ? d_out_axi_data  :
                            o_bar_hit[DMA_SELECT]     ? dma_out_axi_data:
                            32'h0;

assign  s_axis_tx_tkeep   = o_bar_hit[CONTROL_SELECT] ? c_out_axi_keep  :
                            o_bar_hit[DATA_SELECT]    ? d_out_axi_keep  :
                            o_bar_hit[DMA_SELECT]     ? dma_out_axi_keep:
                            4'b0000;

assign  s_axis_tx_tlast   = o_bar_hit[CONTROL_SELECT] ? c_out_axi_last  :
                            o_bar_hit[DATA_SELECT]    ? d_out_axi_last  :
                            o_bar_hit[DMA_SELECT]     ? dma_out_axi_last:
                            1'b0;


assign  s_axis_tx_tvalid  = o_bar_hit[CONTROL_SELECT] ? c_out_axi_valid :
                            o_bar_hit[DATA_SELECT]    ? d_out_axi_valid :
                            o_bar_hit[DMA_SELECT]     ? dma_out_axi_valid :
                            1'b0;

//Strobe the cfg_enable whenever the pcie core relinquishes control
assign  cfg_enable  =  read_bar_addr_stb;

assign  cfg_interrupt_di  = i_interrupt_channel;

//synchronous logic
localparam  IDLE = 0;
localparam  SEND_INTERRUPT = 1;

reg int_state = IDLE;

always @ (posedge clk_62p5) begin
  if (pcie_reset) begin
    cfg_interrupt         <=  0;
    int_state             <=  IDLE;
  end
  else begin
    case (int_state)
      IDLE: begin
        cfg_interrupt     <=  0;
        if (i_interrupt_stb)
          int_state       <=  SEND_INTERRUPT;
      end
      SEND_INTERRUPT: begin
        cfg_interrupt     <=  1;
        if (cfg_interrupt_rdy) begin
          int_state       <=  IDLE;
          cfg_interrupt   <=  0;
        end
      end
    endcase
  end
end

endmodule
