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


//XXX: MAXIMUM PACKET SIZE CANNOT BE OVER THE 'MPS' SETTING FROM THE HOST

module artemis_pcie_controller #(
  parameter DATA_FIFO_DEPTH           = 7,    //512 bytes or 128 32-bit values
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

  // Transaction (TRN) Interface
  output                    user_lnk_up,
 (* KEEP = "TRUE" *) output clk_62p5,

  // Flow Control
  input       [2:0]         fc_sel,
  output      [7:0]         fc_nph,
  output      [11:0]        fc_npd,
  output      [7:0]         fc_ph,
  output      [11:0]        fc_pd,
  output      [7:0]         fc_cplh,
  output      [11:0]        fc_cpld,

  // Conifguration: Interrupt
  output      [31:0]        o_bar_addr0,
  output      [31:0]        o_bar_addr1,
  output      [31:0]        o_bar_addr2,
  output      [31:0]        o_bar_addr3,
  output      [31:0]        o_bar_addr4,
  output      [31:0]        o_bar_addr5,


  // Configuration: Power Management
  input                     cfg_turnoff_ok,
  output                    cfg_to_turnoff,
  input                     cfg_pm_wake,

  // System Interface
  output                    pcie_reset,
  output                    received_hot_reset,
  output                    gtp_reset_done,
  output                    gtp_pll_lock_detect,
  output                    pll_lock_detect,

  //GTP PHY Configurations
  output                    rx_elec_idle,
  input       [1:0]         rx_equalizer_ctrl,
  input       [3:0]         tx_diff_ctrl,
  input       [2:0]         tx_pre_emphasis,

  output      [4:0]         cfg_ltssm_state,


  //Extra Info
  output      [6:0]         o_bar_hit,
  output                    o_receive_axi_ready,

  output      [2:0]         cfg_pcie_link_state,
  output      [7:0]         cfg_bus_number,
  output      [4:0]         cfg_device_number,
  output      [2:0]         cfg_function_number,



  output      [15:0]        cfg_status,
  output      [15:0]        cfg_command,
  output      [15:0]        cfg_dstatus,
  output      [15:0]        cfg_dcommand,
  output      [15:0]        cfg_lstatus,
  output      [15:0]        cfg_lcommand,

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


  //Debug
  output      [7:0]         o_cfg_read_exec,
  output      [3:0]         o_cfg_sm_state,
  output      [7:0]         o_ingress_count,
  output      [3:0]         o_ingress_state,
  output      [7:0]         o_ingress_ri_count,
  output      [7:0]         o_ingress_ci_count,
  output      [31:0]        o_ingress_addr,


  //User Interfaces
  output                    o_per_fifo_sel,
  output                    o_mem_fifo_sel,
  output                    o_dma_fifo_sel,

  output      [31:0]        o_data_size,
  output      [31:0]        o_data_address,
  output                    o_data_fifo_flg,
  output                    o_data_read_flg,
  output                    o_data_write_flg,


  //Ingress FIFO
  input                     i_data_clk,
  output                    o_ingress_fifo_rdy,
  input                     i_ingress_fifo_act,
  output      [23:0]        o_ingress_fifo_size,
  input                     i_ingress_fifo_stb,
  output      [31:0]        o_ingress_fifo_data,

  //Egress FIFO
  input       [1:0]         o_egress_fifo_rdy,
  output      [1:0]         i_egress_fifo_act,
  output      [23:0]        o_egress_fifo_size,
  input                     i_egress_fifo_stb,
  input       [31:0]        i_egress_fifo_data

);

//local parameters
localparam      DATA_FIFO_SIZE    = (2 ** DATA_FIFO_DEPTH);

//registes/wires

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

reg                         cfg_interrupt;
wire                        cfg_interrupt_rdy;
wire                        cfg_interrupt_assert;
wire          [7:0]         cfg_interrupt_do;
wire          [7:0]         cfg_interrupt_di;
wire          [2:0]         cfg_interrupt_mmenable;
wire                        cfg_interrupt_msienable;

wire          [7:0]         w_interrupt_msi_value;
wire                        w_interrupt_stb;

//XXX: Configuration Registers this should be read in by the controller
wire          [31:0]        w_write_a_addr;
wire          [31:0]        w_write_b_addr;
wire          [31:0]        w_read_a_addr;
wire          [31:0]        w_read_b_addr;
wire          [31:0]        w_status_addr;
wire          [31:0]        w_buffer_size;
wire          [31:0]        w_ping_value;
wire          [31:0]        w_dev_addr;
wire          [1:0]         w_update_buf;
wire                        w_update_buf_stb;

//XXX: Control SM Signals
wire          [31:0]        w_control_addr_base;
wire          [31:0]        w_cmd_data_count;
wire          [31:0]        w_cmd_data_address;

assign  w_control_addr_base = o_bar_addr0;


//XXX: These signals are controlled by the buffer controller
//BUFFER Interface
wire          [31:0]        w_buf_offset; //Should be connected to buffer controller to indicate where the buffer is located
wire                        w_buf_we;
wire          [31:0]        w_buf_addr;
wire          [31:0]        w_buf_dat;

assign  w_buf_offset  = 32'h00000000;     //DEBUG Configuration

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

wire                        dbg_reg_detected_correctable;
wire                        dbg_reg_detected_fatal;
wire                        dbg_reg_detected_non_fatal;
wire                        dbg_reg_detected_unsupported;

wire                        dbg_bad_dllp_status;
wire                        dbg_bad_tlp_lcrc;
wire                        dbg_bad_tlp_seq_num;
wire                        dbg_bad_tlp_status;
wire                        dbg_dl_protocol_status;
wire                        dbg_fc_protocol_err_status;
wire                        dbg_mlfrmd_length;
wire                        dbg_mlfrmd_mps;
wire                        dbg_mlfrmd_tcvc;
wire                        dbg_mlfrmd_tlp_status;
wire                        dbg_mlfrmd_unrec_type;
wire                        dbg_poistlpstatus;
wire                        dbg_rcvr_overflow_status;
wire                        dbg_rply_rollover_status;
wire                        dbg_rply_timeout_status;
wire                        dbg_ur_no_bar_hit;
wire                        dbg_ur_pois_cfg_wr;
wire                        dbg_ur_status;
wire                        dbg_ur_unsup_msg;

wire                        w_enable_config_read;
wire                        w_finished_config_read;

wire                        w_reg_write_stb;

//Command Strobe Signals
wire                        w_cmd_rst_stb;
wire                        w_cmd_wr_stb;
wire                        w_cmd_rd_stb;
wire                        w_cmd_ping_stb;
wire                        w_cmd_rd_cfg_stb;
wire                        w_cmd_unknown_stb;

//Command Flag Signals
wire                        w_cmd_flg_fifo_stb;
wire                        w_cmd_flg_sel_per_stb;
wire                        w_cmd_flg_sel_mem_stb;
wire                        w_cmd_flg_sel_dma_stb;

//Egress FIFO Signals
wire                        w_egress_enable;
wire                        w_egress_finished;
wire  [7:0]                 w_egress_tlp_command;
wire  [13:0]                w_egress_tlp_flags;
wire  [31:0]                w_egress_tlp_address;
wire  [15:0]                w_egress_tlp_requester_id;
wire  [7:0]                 w_egress_tag;



/****************************************************************************
 * Egress FIFO Signals
 ****************************************************************************/

wire                        w_ctr_fifo_sel;
wire                        w_dat_fifo_sel;

wire                        w_egress_fifo_rdy;
wire                        w_egress_fifo_act;
wire  [23:0]                w_egress_fifo_size;
wire  [31:0]                w_egress_fifo_data;
wire                        w_egress_fifo_stb;

wire                        w_e_ctr_fifo_rdy;
wire                        w_e_ctr_fifo_act;
wire  [23:0]                w_e_ctr_fifo_size;
wire  [31:0]                w_e_ctr_fifo_data;
wire                        w_e_ctr_fifo_stb;

wire                        w_e_per_fifo_rdy;
wire                        w_e_per_fifo_act;
wire  [23:0]                w_e_per_fifo_size;
wire  [31:0]                w_e_per_fifo_data;
wire                        w_e_per_fifo_stb;

wire                        w_e_mem_fifo_rdy;
wire                        w_e_mem_fifo_act;
wire  [23:0]                w_e_mem_fifo_size;
wire  [31:0]                w_e_mem_fifo_data;
wire                        w_e_mem_fifo_stb;

wire                        w_e_dma_fifo_rdy;
wire                        w_e_dma_fifo_act;
wire  [23:0]                w_e_dma_fifo_size;
wire  [31:0]                w_e_dma_fifo_data;
wire                        w_e_dma_fifo_stb;


wire                        tmp_pcie_fc_ready;


wire  [31:0]                tmp_buf_offset;
wire  [31:0]                tmp_buf_addr;
wire                        tmp_buf_we;
wire  [31:0]                tmp_buf_data;

wire  [1:0]                 w_i_data_fifo_rdy;
wire  [1:0]                 w_o_data_fifo_act;
wire  [23:0]                w_o_data_fifo_size;
wire                        w_i_data_fifo_stb;
wire  [31:0]                w_i_data_fifo_data;


wire                        w_e_data_fifo_rdy;
wire                        w_e_data_fifo_act;
wire  [23:0]                w_e_data_fifo_size;
wire                        w_e_data_fifo_stb;
wire  [31:0]                w_e_data_fifo_data;



/****************************************************************************
 * Interrupt State Machine Signals
 ****************************************************************************/
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
  .cfg_trn_pending                   (cfg_trn_pending         ),  //XXX: Do I need to use cfg_trn_pending??
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

/****************************************************************************
 * Read the BAR Addresses from Config Space
 ****************************************************************************/
config_parser cfg (
  .rst                        (pcie_reset                 ),
  .clk                        (clk_62p5                   ),

  .i_en                       (w_enable_config_read       ),
  .o_finished                 (w_finished_config_read     ),

  .i_cfg_do                   (cfg_do                     ),
  .i_cfg_rd_wr_done           (cfg_rd_wr_done             ),
  .o_cfg_dwaddr               (cfg_dwaddr                 ),
  .o_cfg_rd_en                (cfg_rd_en                  ),


  .o_bar_addr0                (o_bar_addr0                ),
  .o_bar_addr1                (o_bar_addr1                ),
  .o_bar_addr2                (o_bar_addr2                ),
  .o_bar_addr3                (o_bar_addr3                ),
  .o_bar_addr4                (o_bar_addr4                ),
  .o_bar_addr5                (o_bar_addr5                )
);

pcie_control controller(
  .clk                        (clk_62p5                   ),
  .rst                        (pcie_reset                 ),

  //Configuration Values
  .i_pcie_bus_num             (cfg_bus_number             ),
  .i_pcie_dev_num             (cfg_device_number          ),
  .i_pcie_fun_num             (cfg_function_number        ),

  //Ingress Machine Interface
  .i_write_a_addr             (w_write_a_addr             ),
  .i_write_b_addr             (w_write_b_addr             ),
  .i_read_a_addr              (w_read_a_addr              ),
  .i_read_b_addr              (w_read_b_addr              ),
  .i_status_addr              (w_status_addr              ),
  .i_buffer_size              (w_buffer_size              ),
  .i_ping_value               (w_ping_value               ),
  .i_dev_addr                 (w_dev_addr                 ),
  .i_update_buf               (w_update_buf               ),
  .i_update_buf_stb           (w_update_buf_stb           ),

  .i_reg_write_stb            (w_reg_write_stb            ),
  //.i_device_select            (w_device_select            ),

  .i_cmd_rst_stb              (w_cmd_rst_stb              ),
  .i_cmd_wr_stb               (w_cmd_wr_stb               ),
  .i_cmd_rd_stb               (w_cmd_rd_stb               ),
  .i_cmd_ping_stb             (w_cmd_ping_stb             ),
  .i_cmd_rd_cfg_stb           (w_cmd_rd_cfg_stb           ),
  .i_cmd_unknown              (w_cmd_unknown_stb          ),
  .i_cmd_flg_fifo             (w_cmd_flg_fifo_stb         ),
  .i_cmd_flg_sel_periph       (w_cmd_flg_sel_per_stb      ),
  .i_cmd_flg_sel_memory       (w_cmd_flg_sel_mem_stb      ),
  .i_cmd_flg_sel_dma          (w_cmd_flg_sel_dma_stb      ),

  .i_cmd_data_count           (w_cmd_data_count           ),
  .i_cmd_data_address         (w_cmd_data_address         ),

  .i_pcie_fc_ready            (tmp_pcie_fc_ready          ),

  .o_ctr_sel                  (w_ctr_fifo_sel             ),

  //User Interface
  .o_per_sel                  (o_per_fifo_sel             ),
  .o_mem_sel                  (o_mem_fifo_sel             ),
  .o_dma_sel                  (o_dma_fifo_sel             ),

  .o_data_size                (o_data_size                ),
  .o_data_address             (o_data_address             ),
  .o_data_fifo_flg            (o_data_fifo_flg            ),
  .o_data_read_flg            (o_data_read_flg            ),
  .o_data_write_flg           (o_data_write_flg           ),


  //Peripheral/Memory/DMA Egress FIFO Interface
  .i_e_fifo_rdy               (w_egress_fifo_rdy          ),
  .i_e_fifo_size              (w_egress_fifo_size         ),

  //Egress Controller Interface
  .o_egress_enable            (w_egress_enable            ),
  .i_egress_finished          (w_egress_finished          ),
  .o_egress_tlp_command       (w_egress_tlp_command       ),
  .o_egress_tlp_flags         (w_egress_tlp_flags         ),
  .o_egress_tlp_address       (w_egress_tlp_address       ),
  .o_egress_tlp_requester_id  (w_egress_tlp_requester_id  ),
  .o_egress_tag               (w_egress_tag               ),

  .o_interrupt_msi_value      (w_interrupt_msi_value      ),
  .o_interrupt_stb            (w_interrupt_stb            ),

  .o_egress_fifo_rdy          (w_e_ctr_fifo_rdy           ),
  .i_egress_fifo_act          (w_e_ctr_fifo_act           ),
  .o_egress_fifo_size         (w_e_ctr_fifo_size          ),
  .i_egress_fifo_stb          (w_e_ctr_fifo_stb           ),
  .o_egress_fifo_data         (w_e_ctr_fifo_data          ),

  //System Interface
  .o_sys_rst                  (o_sys_rst                  ),

  //Configuration Reader Interface
  .o_cfg_read_exec            (o_cfg_read_exec            ),
  .o_cfg_sm_state             (o_cfg_sm_state             )
);


//XXX: Need to think about resets

/****************************************************************************
 * Single IN/OUT FIFO Solution (This Can Change in the future):
 *  Instead of dedicating unique FIFOs for each bus, I can just doe one
 *  FIFO. This will reduce the size of the core at the cost of
 *  a certain amount of time it will take to fill up the FIFOs
 ****************************************************************************/

//INGRESS FIFO
ppfifo #(
  .DATA_WIDTH       (32                  ),
  .ADDRESS_WIDTH    (DATA_FIFO_DEPTH     ) //16 32-bit values for the control
) i_data_fifo(
  .reset            (pcie_reset || rst   ),
  //Write Side
  .write_clock      (clk_62p5            ),
  .write_ready      (w_i_data_fifo_rdy   ),
  .write_activate   (w_o_data_fifo_act   ),
  .write_fifo_size  (w_o_data_fifo_size  ),
  .write_strobe     (w_i_data_fifo_stb   ),
  .write_data       (w_i_data_fifo_data  ),

  //Read Side
  .read_clock       (i_data_clk           ),
  .read_ready       (o_ingress_fifo_rdy   ),
  .read_activate    (i_ingress_fifo_act   ),
  .read_count       (o_ingress_fifo_size  ),
  .read_strobe      (i_ingress_fifo_stb   ),
  .read_data        (o_ingress_fifo_data  )
);

//EGRESS FIFOs
ppfifo #(
  .DATA_WIDTH       (32                  ),
  .ADDRESS_WIDTH    (DATA_FIFO_DEPTH     ) //16 32-bit values for the control
) e_data_fifo(
  .reset            (pcie_reset || rst   ),
  //Write Side
  .write_clock      (i_data_clk          ),
  .write_ready      (o_egress_fifo_rdy   ),
  .write_activate   (i_egress_fifo_act   ),
  .write_fifo_size  (o_egress_fifo_size  ),
  .write_strobe     (i_egress_fifo_stb   ),
  .write_data       (i_egress_fifo_data  ),

  //Read Side
  .read_clock       (clk_62p5           ),
  .read_ready       (w_e_data_fifo_rdy   ),
  .read_activate    (w_e_data_fifo_act   ),
  .read_count       (w_e_data_fifo_size  ),
  .read_strobe      (w_e_data_fifo_stb   ),
  .read_data        (w_e_data_fifo_data  )
);



pcie_ingress ingress(
  .clk                        (clk_62p5                   ),
  .rst                        (pcie_reset                 ),

  //AXI Stream Host 2 Device
  .o_axi_ingress_ready        (m_axis_rx_tready           ),
  .i_axi_ingress_data         (m_axis_rx_tdata            ),
  .i_axi_ingress_keep         (m_axis_rx_tkeep            ),
  .i_axi_ingress_last         (m_axis_rx_tlast            ),
  .i_axi_ingress_valid        (m_axis_rx_tvalid           ),

  //Configuration
  .o_reg_write_stb            (w_reg_write_stb            ),  //Strobes when new register data is detected

  //Parsed out Register Values
  .o_write_a_addr             (w_write_a_addr             ),
  .o_write_b_addr             (w_write_b_addr             ),
  .o_read_a_addr              (w_read_a_addr              ),
  .o_read_b_addr              (w_read_b_addr              ),
  .o_status_addr              (w_status_addr              ),
  .o_buffer_size              (w_buffer_size              ),
  .o_ping_value               (w_ping_value               ),
  .o_dev_addr                 (w_dev_addr                 ),
  .o_update_buf               (w_update_buf               ),
  .o_update_buf_stb           (w_update_buf_stb           ),

  //Command Interface
  //.o_device_select            (w_device_select            ),

  .o_cmd_rst_stb              (w_cmd_rst_stb              ),  //Strobe when a reset command is detected
  .o_cmd_wr_stb               (w_cmd_wr_stb               ),  //Strobes when a write request is detected
  .o_cmd_rd_stb               (w_cmd_rd_stb               ),  //Strobes when a read request is detected
  .o_cmd_ping_stb             (w_cmd_ping_stb             ),  //Strobes when a ping request is detected
  .o_cmd_rd_cfg_stb           (w_cmd_rd_cfg_stb           ),  //Strobes when a read configuration id detected
  .o_cmd_unknown_stb          (w_cmd_unknown_stb          ),

  .o_cmd_flg_fifo_stb         (w_cmd_flg_fifo_stb         ),  //Flag indicating that transfer shouldn't auto increment addr
  .o_cmd_flg_sel_per_stb      (w_cmd_flg_sel_per_stb      ),
  .o_cmd_flg_sel_mem_stb      (w_cmd_flg_sel_mem_stb      ),
  .o_cmd_flg_sel_dma_stb      (w_cmd_flg_sel_dma_stb      ),

  //Input Configuration Registers from either PCIE_A1 or controller
  .i_bar_hit                  (o_bar_hit                  ),
  //Local Address of where BAR0 is located (Used to do address translation)
  .i_control_addr_base        (w_control_addr_base        ),
  .o_enable_config_read       (w_enable_config_read       ),
  .i_finished_config_read     (w_finished_config_read     ),

  //When a command is detected the size of the transaction is reported here
  .o_cmd_data_count           (w_cmd_data_count           ),
  .o_cmd_data_address         (w_cmd_data_address         ),

  //Buffer interface, the buffer controller will manage this
  .i_buf_offset               (tmp_buf_offset             ),
  .o_buf_we                   (tmp_buf_we                 ),
  .o_buf_addr                 (tmp_buf_addr               ),
  .o_buf_data                 (tmp_buf_data               ),
  .o_state                    (o_ingress_state            ),
  .o_ingress_count            (o_ingress_count            ),
  .o_ingress_ri_count         (o_ingress_ri_count         ),
  .o_ingress_ci_count         (o_ingress_ci_count         ),
  .o_ingress_addr             (o_ingress_addr             )
);

pcie_egress egress(
  .clk                        (clk_62p5                   ),
  .rst                        (pcie_reset                 ),

  .i_enable                   (w_egress_enable            ),
  .o_finished                 (w_egress_finished          ),
  .i_command                  (w_egress_tlp_command       ),
  .i_flags                    (w_egress_tlp_flags         ),
  .i_address                  (w_egress_tlp_address       ),
  .i_requester_id             (w_egress_tlp_requester_id  ),
  .i_tag                      (w_egress_tag               ),

  .i_axi_egress_ready         (s_axis_tx_tready           ),
  .o_axi_egress_data          (s_axis_tx_tdata            ),
  .o_axi_egress_keep          (s_axis_tx_tkeep            ),
  .o_axi_egress_last          (s_axis_tx_tlast            ),
  .o_axi_egress_valid         (s_axis_tx_tvalid           ),

  .i_fifo_rdy                 (w_egress_fifo_rdy          ),
  .o_fifo_act                 (w_egress_fifo_act          ),
  .i_fifo_size                (w_egress_fifo_size         ),
  .i_fifo_data                (w_egress_fifo_data         ),
  .o_fifo_stb                 (w_egress_fifo_stb          )
);

/****************************************************************************
 * FIFO Multiplexer
 ****************************************************************************/
assign  w_egress_fifo_rdy     = (w_ctr_fifo_sel)      ? w_e_ctr_fifo_rdy:
                                (w_dat_fifo_sel)      ? w_e_data_fifo_rdy:
                                1'b0;

assign  w_egress_fifo_size    = (w_ctr_fifo_sel)      ? w_e_ctr_fifo_size:
                                (w_dat_fifo_sel)      ? w_e_data_fifo_size:
                                24'h0;

assign  w_egress_fifo_data    = (w_ctr_fifo_sel)      ? w_e_ctr_fifo_data:
                                (w_dat_fifo_sel)      ? w_e_data_fifo_data:
                                32'h00;

assign  w_e_ctr_fifo_act      = (w_ctr_fifo_sel)      ? w_egress_fifo_act:
                                  1'b0;
assign  w_e_ctr_fifo_stb      = (w_ctr_fifo_sel)      ? w_egress_fifo_stb:
                                  1'b0;

assign  w_e_data_fifo_act     = (w_dat_fifo_sel)      ? w_egress_fifo_act:
                                 1'b0;
assign  w_e_data_fifo_stb     = (w_dat_fifo_sel)      ? w_egress_fifo_stb:
                                 1'b0;

assign  w_dat_fifo_sel        = (o_per_fifo_sel || o_mem_fifo_sel || o_dma_fifo_sel);
/****************************************************************************
 * Temporary Debug Signals
 ****************************************************************************/

//This used to go to the wishbone slave device
assign  o_receive_axi_ready = 0;

//Need to create a flow controller
assign  tmp_pcie_fc_ready = 1;

assign  tmp_buf_offset  = 32'h0;


assign  w_i_data_fifo_act    = 0;
assign  w_i_data_fifo_stb    = 0;
assign  w_i_data_fifo_data   = 0;




/****************************************************************************
 * AXI Signals from the user to the PCIE_A1 Core
 ****************************************************************************/
assign  s_axis_tx_discont     = 0;
assign  s_axis_tx_stream      = 0;
assign  s_axis_tx_err_fwd     = 0;
assign  s_axis_tx_s6_not_used = 0;

assign  s_axis_tx_tuser       = {s_axis_tx_discont,
                                 s_axis_tx_stream,
                                 s_axis_tx_err_fwd,
                                 s_axis_tx_s6_not_used};

//Use this BAR Hist because it is buffered with the AXI transaction
assign  o_bar_hit             = m_axis_rx_tuser[8:2];

/****************************************************************************
 * The Following Signals Need to be integrated into the core
 ****************************************************************************/
//XXX: THIS SIGNAL MIGHT NEED TO BE SET HIGH WHEN AN UPSTREAM DATA REQUEST IS SENT
assign  cfg_trn_pending       =  1'b0;
//Allow PCIE_A1 Core to have priority over transactions
assign  tx_cfg_gnt            =  1'b1;
//Allow PCIE_A1 Core to send non-posted transactions to the user application (Flow Control from user app)
assign  rx_np_ok              =  1'b1;



/****************************************************************************
 * Add the configuration state machine controller to a command, the user
 * should be able to send an initialization signal from the host, this will
 * Trigger the configuration controller to read the internal address register
 * of the bars... is this needed anymore? The host will only write small
 * transactions to configure the state machine, there doesn't seem to be a
 * reason for the configuration state machine any more
 ****************************************************************************/

//assign  cfg_interrupt_di  = i_interrupt_channel;
//assign  cfg_interrupt_stb = i_interrupt_stb;
assign  cfg_interrupt_di  = w_interrupt_msi_value;
assign  cfg_interrupt_stb = w_interrupt_stb;


/****************************************************************************
 * Interrupt State Machine
 ****************************************************************************/
//asynchronous logic
//synchronous logic
localparam  IDLE            = 0;
localparam  SEND_INTERRUPT  = 1;

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
        if (cfg_interrupt_stb)
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
