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
 * Author: David McCoy (dave.mccoy@cospandesign.com)
 * Description:
 *
 * Changes:
 */
`timescale 1ps / 1ps

module artemis_pcie_interface #(
  // Number of RIFFA Channels (Peripheral, Memory, DMA)
  parameter C_NUM_CHNL                        = 3,
  // Bit-Width from Vivado IP Generator
  parameter C_PCI_DATA_WIDTH                  = 32,
  // 4-Byte Name for this FPGA
  parameter C_MAX_PAYLOAD_BYTES               = 256,
  parameter C_LOG_NUM_TAGS                    = 8,
  parameter C_SERIAL_NUMBER                   = 64'h000000000000C594
  parameter C_FPGA_ID                         = "KC105" //??
)(
  input                                         i_interrupt,          // FPGA Initiated an Interrupt (This may not be implemented yet!)
  output                                        o_user_lnk_up,

  output                                        o_pcie_rst_out,
  // Data Interface
  input   [C_NUM_CHNL-1:0]                      i_chnl_rx_clk,        // Channel read clock
  output  [C_NUM_CHNL-1:0]                      o_chnl_rx,            // Channel read receive signal
  input   [C_NUM_CHNL-1:0]                      i_chnl_rx_ack,        // Channel read received signal
  output  [C_NUM_CHNL-1:0]                      o_chnl_rx_last,       // Channel last read
  output  [(C_NUM_CHNL*`SIG_CHNL_LENGTH_W)-1:0] o_chnl_rx_len,        // Channel read length
  output  [(C_NUM_CHNL*`SIG_CHNL_OFFSET_W)-1:0] o_chnl_rx_off,        // Channel read offset
  output  [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0]   o_chnl_rx_data,       // Channel read data
  output  [C_NUM_CHNL-1:0]                      o_chnl_rx_data_valid, // Channel read data valid
  input   [C_NUM_CHNL-1:0]                      i_chnl_rx_data_ren,   // Channel read data has been recieved

  input   [C_NUM_CHNL-1:0]                      i_chnl_tx_clk,        // Channel write clock
  input   [C_NUM_CHNL-1:0]                      i_chnl_tx,            // Channel write receive signal
  output  [C_NUM_CHNL-1:0]                      o_chnl_tx_ack,        // Channel write acknowledgement signal
  input   [C_NUM_CHNL-1:0]                      i_chnl_tx_last,       // Channel last write
  input   [(C_NUM_CHNL*`SIG_CHNL_LENGTH_W)-1:0] i_chnl_tx_len,        // Channel write length (in 32 bit words)
  input   [(C_NUM_CHNL*`SIG_CHNL_OFFSET_W)-1:0] i_chnl_tx_off,        // Channel write offset
  input   [(C_NUM_CHNL*C_PCI_DATA_WIDTH)-1:0]   i_chnl_tx_data,       // Channel write data
  input   [C_NUM_CHNL-1:0]                      i_chnl_tx_data_valid, // Channel write data valid
  output  [C_NUM_CHNL-1:0]                      o_chnl_tx_data_ren    // Channel write data has been recieved

  //Phy Interface
  input                                         i_pcie_phy_clk_p,
  input                                         i_pcie_phy_clk_n,

  output                                        o_pcie_phy_tx_p,
  output                                        o_pcie_phy_tx_n,

  input                                         i_pcie_phy_rx_p,
  input                                         i_pcie_phy_rx_n
);
//local parameters
//registes/wires

// Interface: Xilinx RX
wire    [C_PCI_DATA_WIDTH-1:0]                m_axis_rx_tdata;
wire    [(C_PCI_DATA_WIDTH/8)-1:0]            m_axis_rx_tkeep;
wire                                          m_axis_rx_tlast;
wire                                          m_axis_rx_tvalid;
wire                                          m_axis_rx_tready;
wire    [`SIG_XIL_RX_TUSER_W-1:0]             m_axis_rx_tuser;
wire                                          rx_np_ok;
wire                                          rx_np_req;

// Interface: Xilinx TX
wire    [C_PCI_DATA_WIDTH-1:0]                s_axis_tx_tdata;
wire    [(C_PCI_DATA_WIDTH/8)-1:0]            s_axis_tx_tkeep;
wire                                          s_axis_tx_tlast;
wire                                          s_axis_tx_tvalid;
wire                                          s_axis_tx_tready;
wire    [`SIG_XIL_TX_TUSER_W-1:0]             s_axis_tx_tuser;
wire                                          tx_cfg_gnt;

// Interface: Xilinx Configuration
wire    [`SIG_BUSID_W-1:0]                    cfg_bus_number;
wire    [`SIG_DEVID_W-1:0]                    cfg_device_number;
wire    [`SIG_FNID_W-1:0]                     cfg_function_number;
wire    [`SIG_CFGREG_W-1:0]                   cfg_command;
wire    [`SIG_CFGREG_W-1:0]                   cfg_dcommand;
wire    [`SIG_CFGREG_W-1:0]                   cfg_lstatus;
wire    [`SIG_CFGREG_W-1:0]                   cfg_lcommand;

// Interface: Xilinx Flow Control
wire    [`SIG_FC_CPLD_W-1:0]                  fc_cpld;
wire    [`SIG_FC_CPLH_W-1:0]                  fc_cplh;
wire    [`SIG_FC_SEL_W-1:0]                   fc_sel;

// Interface: Xilinx Interrupt
wire                                          cfg_interrupt_msien;
wire                                          cfg_interrupt_rdy;
wire                                          cfg_interrupt;

wire                                          cfg_turnoff_ok;
wire                                          cfg_trn_pending;
wire                                          cfg_pm_halt_aspm_l0s;
wire                                          cfg_pm_halt_aspm_l1;
wire                                          cfg_pm_force_state_en;
wire [1:0]                                    cfg_pm_force_state;
wire                                          cfg_pm_wake;
wire [63:0]                                   cfg_dsn;


wire [9:0]                                    cfg_dwaddr;
wire                                          cfg_rd_en;
wire                                          cfg_err_ur;
wire                                          cfg_err_cor;
wire                                          cfg_err_ecrc;
wire                                          cfg_err_cpl_timeout;
wire                                          cfg_err_cpl_abort;
wire                                          cfg_err_posted;
wire                                          cfg_err_locked;
wire [47:0]                                   cfg_err_tlp_cpl_header;

//submodules
riffa_wrapper_cd_artemis #(
  // Number of RIFFA Channels (Peripheral, Memory, DMA)
  .C_NUM_CHNL                                 (C_NUM_CHNL           ),
  // Bit-Width from Vivado IP Generator
  .C_PCI_DATA_WIDTH                           (C_PCI_DATA_WIDTH     ),
  // 4-Byte Name for this FPGA
  .C_MAX_PAYLOAD_BYTES                        (C_MAX_PAYLOAD_BYTES  ),
  .C_LOG_NUM_TAGS                             (C_LOG_NUM_TAGS       ),
  .C_FPGA_ID                                  (C_FPGA_ID            )
) riffa_wrapper (

  .RST_OUT                                    (pcie_rst_out         ),

  // Interface: Xilinx RX
  .M_AXIS_RX_TDATA                            (m_axis_rx_tdata      ),
  .M_AXIS_RX_TKEEP                            (m_axis_rx_tkeep      ),
  .M_AXIS_RX_TLAST                            (m_axis_rx_tlast      ),
  .M_AXIS_RX_TVALID                           (m_axis_rx_tvalid     ),
  .M_AXIS_RX_TREADY                           (m_axis_rx_tready     ),
  .M_AXIS_RX_TUSER                            (m_axis_rx_tuser      ),
  .RX_NP_OK                                   (rx_np_ok             ),
  .RX_NP_REQ                                  (rx_np_req            ),

  // Interface: Xilinx TX
  .S_AXIS_TX_TDATA                            (s_axis_tx_tdata      ),
  .S_AXIS_TX_TKEEP                            (s_axis_tx_tkeep      ),
  .S_AXIS_TX_TLAST                            (s_axis_tx_tlast      ),
  .S_AXIS_TX_TVALID                           (s_axis_tx_tvalid     ),
  .S_AXIS_TX_TREADY                           (s_axis_tx_tready     ),
  .S_AXIS_TX_TUSER                            (s_axis_tx_tuser      ),
  .TX_CFG_GNT                                 (tx_cfg_gnt           ),

  // Interface: Xilinx Configuration
  .CFG_BUS_NUMBER                             (cfg_bus_number       ),
  .CFG_DEVICE_NUMBER                          (cfg_device_number    ),
  .CFG_FUNCTION_NUMBER                        (cfg_function_number  ),
  .CFG_COMMAND                                (cfg_command          ),
  .CFG_DCOMMAND                               (cfg_dcommand         ),
  .CFG_LSTATUS                                (cfg_lstatus          ),
  .CFG_LCOMMAND                               (cfg_lcommand         ),

  // Interface: Xilinx Flow Control
  .FC_CPLD                                    (fc_cpld              ),
  .FC_CPLH                                    (fc_cplh              ),
  .FC_SEL                                     (fc_sel               ),

  // Interface: Xilinx Interrupt
  .CFG_INTERRUPT_MSIEN                        (cfg_interrupt_msien  ),
  .CFG_INTERRUPT_RDY                          (cfg_interrupt_rdy    ),
  .CFG_INTERRUPT                              (cfg_interrupt        ),


  //User Interface
  .USER_CLK                                   (user_clk_out         ),
  .USER_RESET                                 (o_pcie_rst_out       ),

  // Data Interface
  .CHNL_RX_CLK                                (chnl_rx_clk          ),
  .CHNL_RX                                    (chnl_rx              ),
  .CHNL_RX_ACK                                (chnl_rx_ack          ),
  .CHNL_RX_LAST                               (chnl_rx_last         ),
  .CHNL_RX_LEN                                (chnl_rx_len          ),
  .CHNL_RX_OFF                                (chnl_rx_off          ),
  .CHNL_RX_DATA                               (chnl_rx_data         ),
  .CHNL_RX_DATA_VALID                         (chnl_rx_data_valid   ),
  .CHNL_RX_DATA_REN                           (chnl_rx_data_ren     ),

  .CHNL_TX_CLK                                (chnl_tx_clk          ),
  .CHNL_TX                                    (chnl_tx              ),
  .CHNL_TX_ACK                                (chnl_tx_ack          ),
  .CHNL_TX_LAST                               (chnl_tx_last         ),
  .CHNL_TX_LEN                                (chnl_tx_len          ),
  .CHNL_TX_OFF                                (chnl_tx_off          ),
  .CHNL_TX_DATA                               (chnl_tx_data         ),
  .CHNL_TX_DATA_VALID                         (chnl_tx_data_valid   ),
  .CHNL_TX_DATA_REN                           (chnl_tx_data_ren     )

);

Artemis_Gen1x1If32 fpga_pcie (

  // PCI Express Fabric Interface
  .pci_exp_txp                                (o_pcie_phy_tx_p      ),
  .pci_exp_txn                                (o_pcie_phy_tx_n      ),
  .pci_exp_rxp                                (i_pcie_phy_rx_p      ),
  .pci_exp_rxn                                (i_pcie_phy_rx_n      ),

  // Transaction (TRN) Interface
  .user_lnk_up                                (o_user_lnk_up        ),    //Link Up!

  // Tx
  .s_axis_tx_tready                           (s_axis_tx_tready     ),
  .s_axis_tx_tdata                            (s_axis_tx_tdata      ),
  .s_axis_tx_tkeep                            (s_axis_tx_tkeep      ),
  .s_axis_tx_tuser                            (s_axis_tx_tuser      ),
  .s_axis_tx_tlast                            (s_axis_tx_tlast      ),
  .s_axis_tx_tvalid                           (s_axis_tx_tvalid     ),

//  .tx_buf_av                                  (tx_buf_av            ),
//  .tx_err_drop                                (tx_err_drop          ),
  .tx_cfg_gnt                                 (tx_cfg_gnt           ),    //Allow the core to perform Config TX/RX
  .tx_cfg_req                                 (tx_cfg_req           ),

  // Rx
  .m_axis_rx_tdata                            (m_axis_rx_tdata      ),
  .m_axis_rx_tkeep                            (m_axis_rx_tkeep      ),
  .m_axis_rx_tlast                            (m_axis_rx_tlast      ),
  .m_axis_rx_tvalid                           (m_axis_rx_tvalid     ),
  .m_axis_rx_tready                           (m_axis_rx_tready     ),
  .m_axis_rx_tuser                            (m_axis_rx_tuser      ),
  .rx_np_ok                                   (rx_np_ok             ),    //Non-Posted Receive Okay

  .fc_sel                                     (fc_sel               ),    //Flow Control Select
//  .fc_nph                                     (fc_nph               ),
//  .fc_npd                                     (fc_npd               ),
//  .fc_ph                                      (fc_ph                ),
//  .fc_pd                                      (fc_pd                ),
  .fc_cplh                                    (fc_cplh              ),    //Flow Control Completion Header Credits
  .fc_cpld                                    (fc_cpld              ),    //Flow Control Completion Data Credits

  // Host (CFG) Interface
  .cfg_interrupt_msienable                    (cfg_interrupt_msien     ), //Enable MSI Interrupt
  .cfg_interrupt                              (cfg_interrupt           ), //Request to send Interrupt
  .cfg_interrupt_rdy                          (cfg_interrupt_rdy       ), //Interrupt is accepted

  .cfg_bus_number                             (cfg_bus_number          ),
  .cfg_device_number                          (cfg_device_number       ),
  .cfg_function_number                        (cfg_function_number     ),


// .cfg_do                                     (cfg_do                  ),
// .cfg_rd_wr_done                             (cfg_rd_wr_done          ),
// .cfg_dwaddr                                 (cfg_dwaddr              ),
// .cfg_rd_en                                  (cfg_rd_en               ),
// .cfg_err_ur                                 (cfg_err_ur              ),
// .cfg_err_cor                                (cfg_err_cor             ),
// .cfg_err_ecrc                               (cfg_err_ecrc            ),
// .cfg_err_cpl_timeout                        (cfg_err_cpl_timeout     ),
// .cfg_err_cpl_abort                          (cfg_err_cpl_abort       ),
// .cfg_err_posted                             (cfg_err_posted          ),
// .cfg_err_locked                             (cfg_err_locked          ),
// .cfg_err_tlp_cpl_header                     (cfg_err_tlp_cpl_header  ),
// .cfg_err_cpl_rdy                            (cfg_err_cpl_rdy         ),
 .cfg_interrupt_assert                       (cfg_interrupt_assert    ),    //??
 .cfg_interrupt_di                           (cfg_interrupt_di        ),    //Interrupt Value
 .cfg_turnoff_ok                             (cfg_turnoff_ok          ),    //Power Management
 .cfg_pm_wake                                (cfg_pm_wake             ),    //Power Management Wake
 .cfg_trn_pending                            (cfg_trn_pending         ),    //??
 .cfg_dsn                                    (cfg_dsn                 ),    //Serial Number
// .cfg_interrupt_do                           (cfg_interrupt_do        ),
// .cfg_interrupt_mmenable                     (cfg_interrupt_mmenable  ),
// .cfg_to_turnoff                             (cfg_to_turnoff          ),
// .cfg_pcie_link_state                        (cfg_pcie_link_state     ),
// .cfg_status                                 (cfg_status              ),
// .cfg_command                                (cfg_command             ),
// .cfg_dstatus                                (cfg_dstatus             ),
// .cfg_dcommand                               (cfg_dcommand            ),
// .cfg_lstatus                                (cfg_lstatus             ),
// .cfg_lcommand                               (cfg_lcommand            ),

 // System Interface
//  .received_hot_reset                         (received_hot_reset      )  //??
  .sys_clk                                    (sys_clk                 ), // Incomming 100MHz Clock
  .sys_reset                                  (sys_reset               ), //??
  .user_clk_out                               (user_clk_out            ), //Clock used to interface with PCIE
  .user_reset_out                             (o_pcie_rst_out          ), //Reset From the PCIE Core
);


//Change the incomming differential clock into a single clock
IBUFGDS sys_clk_in (
  .I                                          (i_pcie_phy_clk_p        ),
  .IB                                         (i_pcie_phy_clk_n        ),

  .O                                          (sys_clk                 )
);

//asynchronous logic
assign cfg_turnoff_ok               = 0;
assign cfg_pm_wake                  = 0;
assign cfg_trn_pending              = 0;
assign cfg_dsn                      = C_SERIAL_NUMBER;
assign cfg_interrupt_assert         = 0;
assign cfg_interrupt_di             = 0;
assign cfg_interrupt_stat           = 0;
assign cfg_dwaddr                   = 0;
assign cfg_rd_en                    = 0;
assign cfg_err_ur                   = 0;
assign cfg_err_cor                  = 0;
assign cfg_err_ecrc                 = 0;
assign cfg_err_cpl_timeout          = 0;
assign cfg_err_cpl_abort            = 0;
assign cfg_err_posted               = 0;
assign cfg_err_locked               = 0;
assign cfg_err_tlp_cpl_header       = 0;



//synchronous logic

endmodule
