//wb_artemis_pcie_platform.v
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
  Set the Vendor ID (Hexidecimal 64-bit Number)
  SDB_VENDOR_ID:0x800000000000C594

  Set the Device ID (Hexcidecimal 32-bit Number)
  SDB_DEVICE_ID:0x800000000000C594

  Set the version of the Core XX.XXX.XXX Example: 01.000.000
  SDB_CORE_VERSION:00.000.001

  Set the Device Name: 19 UNICODE characters
  SDB_NAME:wb_artemis_pcie_platform

  Set the class of the device (16 bits) Set as 0
  SDB_ABI_CLASS:0

  Set the ABI Major Version: (8-bits)
  SDB_ABI_VERSION_MAJOR:0x0F

  Set the ABI Minor Version (8-bits)
  SDB_ABI_VERSION_MINOR:0

  Set the Module URL (63 Unicode Characters)
  SDB_MODULE_URL:http://www.example.com

  Set the date of module YYYY/MM/DD
  SDB_DATE:2015/12/20

  Device is executable (True/False)
  SDB_EXECUTABLE:True

  Device is readable (True/False)
  SDB_READABLE:True

  Device is writeable (True/False)
  SDB_WRITEABLE:True

  Device Size: Number of Registers
  SDB_SIZE:3
*/
`include "project_defines.v"

`define CTRL_BIT_ENABLE               0
`define CTRL_BIT_SEND_CONTROL_BLOCK   1
`define CTRL_BIT_CANCEL_SEND_BLOCK    2
`define CTRL_BIT_ENABLE_LOCAL_READ    3
`define CTRL_BIT_ENABLE_EXT_RESET     4
`define CTRL_BIT_MANUAL_USER_RESET    5
`define CTRL_BIT_RESET_DBG_REGS       6
`define CTRL_BIT_READ_BAR_ADDR_STB    7
`define CTRL_BIT_SEND_IRQ             8

`define STS_BIT_PCIE_RESET            0
`define STS_BIT_LINKUP                1
`define STS_BIT_RECEIVED_HOT_RESET    2
`define STS_BITS_PCIE_LINK_STATE      6:4
`define STS_BITS_PCIE_BUS_NUM         15:8
`define STS_BITS_PCIE_DEV_NUM         19:16
`define STS_BITS_PCIE_FUNC_NUM        22:20
`define STS_BITS_LOCAL_MEM_IDLE       24
`define STS_BIT_GTP_PLL_LOCK_DETECT   25
`define STS_BIT_PLL_LOCK_DETECT       26
`define STS_BIT_GTP_RESET_DONE        27
`define STS_BIT_RX_ELEC_IDLE          28
`define STS_BIT_CFG_TO_TURNOFF        29
`define STS_BIT_PCIE_EXT_RESET        30
`define STS_BIT_AXI_RECEIVE_READY     31


`define DBG_DTCT_CRCT                 0
`define DBG_DTCT_FATL                 1
`define DBG_DTCT_NFTL                 2
`define DBG_DTCT_UNSP                 3
`define DBG_DLLP_STS                  4
`define DBG_BD_TLP_LCRC               5
`define DBG_BD_TLP_SQNM               6
`define DBG_BD_TLP_STS                7
`define DBG_DL_PTCL_STS               8
`define DBG_FC_PTCL_STS               9
`define DBG_MLFM_LEN                  10
`define DBG_MLFM_MPS                  11
`define DBG_MLFM_TCVC                 12
`define DBG_MLFM_TLP_STS              13
`define DBG_MLFM_TLP_UNREC            14
`define DBG_PLP_STS                   15
`define DBG_RCVR_OVFL_STS             16
`define DBG_RCVR_RLVR_STS             17
`define DBG_RCVR_TMT_STS              18
`define DBG_UR_NO_BAR                 19
`define DBG_UR_POIS                   20
`define DBG_UR_STS                    21
`define DBG_UR_UNSUP_MSG              22



`define USR_IF_BIT_PER_BUS_SEL        0
`define USR_IF_BIT_MEM_BUS_SEL        1
`define USR_IF_BIT_DMA_BUS_SEL        2
`define USR_IF_BIT_WR_FLAG            3
`define USR_IF_BIT_RD_FLAG            4
`define USR_IF_BIT_FIFO_FLAG          5


`define LOCAL_BUFFER_OFFSET         24'h000100


module wb_artemis_pcie_platform #(
  parameter           DATA_FIFO_DEPTH = 5
) (
  input               clk,
  input               rst,

  //Add signals to control your device here

  //Wishbone Bus Signals
  input               i_wbs_we,
  input               i_wbs_cyc,
  input       [3:0]   i_wbs_sel,
  input       [31:0]  i_wbs_dat,
  input               i_wbs_stb,
  output  reg         o_wbs_ack,
  output  reg [31:0]  o_wbs_dat,
  input       [31:0]  i_wbs_adr,

  //This interrupt can be controlled from this module or a submodule
  output  reg         o_wbs_int,

  //PCIE Physical Signals
  input               i_clk_100mhz_gtp_p,
  input               i_clk_100mhz_gtp_n,

  output              o_pcie_phy_tx_p,
  output              o_pcie_phy_tx_n,

  input               i_pcie_phy_rx_p,
  input               i_pcie_phy_rx_n,

  input               i_pcie_reset_n,
  output              o_pcie_wake_n,

  output              o_62p5_clk,
  output      [31:0]  o_debug_data

);

//Local Parameters
localparam    DATA_BUFFER_SIZE = 2 ** DATA_FIFO_DEPTH;

localparam    CONTROL             = 0;
localparam    STATUS              = 1;
localparam    NUM_BLOCK_READ      = 2;
localparam    LOCAL_BUFFER_SIZE   = 3;
localparam    PCIE_CLOCK_CNT      = 4;
localparam    TEST_CLOCK          = 5;
localparam    TX_DIFF_CTRL        = 6;
localparam    RX_EQUALIZER_CTRL   = 7;
localparam    LTSSM_STATE         = 8;
localparam    TX_PRE_EMPH         = 9;
localparam    DBG_DATA            = 10;

/*
localparam    CONFIG_COMMAND      = 11;
localparam    CONFIG_STATUS       = 12;
localparam    CONFIG_DCOMMAND     = 13;
localparam    CONFIG_DSTATUS      = 14;
localparam    CONFIG_LCOMMAND     = 15;
localparam    CONFIG_LSTATUS      = 16;
*/

localparam    USR_IF_FLAGS        = 11;
localparam    USR_IF_SIZE         = 12;
localparam    USR_IF_ADDRESS      = 13;

localparam    DBG_FLAGS           = 17;
localparam    BAR_SELECT          = 18;
localparam    BAR_ADDR0           = 19;
localparam    BAR_ADDR1           = 20;
localparam    BAR_ADDR2           = 21;
localparam    BAR_ADDR3           = 22;
localparam    BAR_ADDR4           = 23;
localparam    BAR_ADDR5           = 24;
localparam    IRQ_CHANNEL_SELECT  = 25;
localparam    CFG_READ_EXEC       = 26;
localparam    CFG_SM_STATE        = 27;
localparam    CTR_SM_STATE        = 28;
localparam    INGRESS_COUNT       = 29;
localparam    INGRESS_STATE       = 30;
localparam    INGRESS_RI_COUNT    = 31;
localparam    INGRESS_CI_COUNT    = 32;
localparam    INGRESS_ADDR        = 33;


//Local Registers/Wires

wire      [31:0]                status;

reg                             r_enable_pcie = 1;
//reg                             r_enable_ext_reset;
//reg                             r_manual_pcie_reset;
reg       [31:0]                r_clock_1_sec;
reg       [31:0]                r_clock_count;
reg       [31:0]                r_host_clock_count;
reg                             r_1sec_stb_100mhz;
wire                            w_1sec_stb_65mhz;
reg                             r_irq_stb = 0;

// Transaction (TRN) Interface
wire                            user_lnk_up;

  // Flow Control
wire      [2:0]                 fc_sel;
wire      [7:0]                 fc_nph;
wire      [11:0]                fc_npd;
wire      [7:0]                 fc_ph;
wire      [11:0]                fc_pd;
wire      [7:0]                 fc_cplh;
wire      [11:0]                fc_cpld;


// Configuration: Error
wire                             cfg_err_ur;
wire                             cfg_err_cor;
wire                             cfg_err_ecrc;
wire                             cfg_err_cpl_timeout;
wire                             cfg_err_cpl_abort;
wire                             cfg_err_posted;
wire                             cfg_err_locked;
wire      [47:0]                 cfg_err_tlp_cpl_header;
wire                             cfg_err_cpl_rdy;

// Configuration: Power Management
reg                              cfg_turnoff_ok = 0;
reg                              trn_pending = 0;
wire                             cfg_to_turnoff;
wire                             cfg_pm_wake;

// Configuration: System/Status
wire      [2:0]                  cfg_pcie_link_state;
//reg                              r_cfg_trn_pending;
wire      [7:0]                  cfg_bus_number;
wire      [4:0]                  cfg_device_number;
wire      [2:0]                  cfg_function_number;

wire      [15:0]                 cfg_status;
wire      [15:0]                 cfg_command;
wire      [15:0]                 cfg_dstatus;
wire      [15:0]                 cfg_dcommand;
wire      [15:0]                 cfg_lstatus;
wire      [15:0]                 cfg_lcommand;

// System Interface
wire                              pcie_reset;
wire                              clk_62p5;
wire                              received_hot_reset;

reg                               r_ppfifo_2_mem_en;
reg                               r_mem_2_ppfifo_stb;
reg                               r_cancel_write_stb;
wire  [31:0]                      w_num_reads;
wire                              w_idle;
wire                              pll_lock_detect;
wire                              rx_elec_idle;
wire                              gtp_pll_lock_detect;
wire                              gtp_reset_done;

//User Memory Interface
reg                               r_lcl_mem_we;
wire  [DATA_FIFO_DEPTH -1: 0]     w_lcl_mem_addr;
reg   [31:0]                      r_lcl_mem_din;
wire  [31:0]                      w_lcl_mem_dout;
wire                              w_lcl_mem_valid;

wire                              w_lcl_mem_en;


wire                              w_fifo_ingress_rd_stb;
wire                              w_fifo_ingress_rd_ready;
wire                              w_fifo_ingress_rd_activate;
wire  [23:0]                      w_fifo_ingress_rd_size;
wire  [31:0]                      w_fifo_ingress_rd_data;

wire  [1:0]                       w_fifo_egress_wr_ready;
wire  [1:0]                       w_fifo_egress_wr_activate;
wire  [23:0]                      w_fifo_egress_wr_size;
wire                              w_fifo_egress_wr_stb;
wire  [31:0]                      w_fifo_egress_wr_data;



reg   [1:0]                       r_rx_equalizer_ctrl = 2'b11;
reg   [3:0]                       r_tx_diff_ctrl      = 4'h9;
reg   [2:0]                       r_tx_pre_emphasis   = 3'b00;
wire  [4:0]                       cfg_ltssm_state;

wire [6:0]                        w_bar_hit;
wire                              w_receive_axi_ready;
reg  [6:0]                        r_unrecognized_bar;

wire                              w_rx_data_valid;

reg  [6:0]                        r_bar_hit_temp;


wire [31:0]                       w_bar_addr0;
wire [31:0]                       w_bar_addr1;
wire [31:0]                       w_bar_addr2;
wire [31:0]                       w_bar_addr3;
wire [31:0]                       w_bar_addr4;
wire [31:0]                       w_bar_addr5;

wire [7:0]                        w_cfg_read_exec;
wire [3:0]                        w_cfg_sm_state;
wire [3:0]                        w_sm_state;
wire [7:0]                        w_ingress_count;
wire [3:0]                        w_ingress_state;
wire [7:0]                        w_ingress_ri_count;
wire [7:0]                        w_ingress_ci_count;
wire [31:0]                       w_ingress_addr;

wire [31:0]                       w_data_size;
wire [31:0]                       w_data_address;

wire                              w_per_fifo_sel;
wire                              w_mem_fifo_sel;
wire                              w_dma_fifo_sel;
wire                              w_data_fifo_flg;
wire                              w_data_read_flg;
wire                              w_data_write_flg;

wire                              w_usr_interrupt_stb;
wire  [31:0]                      w_usr_interrupt_value;

wire                              dbg_reg_detected_correctable;
wire                              dbg_reg_detected_fatal;
wire                              dbg_reg_detected_non_fatal;
wire                              dbg_reg_detected_unsupported;

wire                              dbg_bad_dllp_status;
wire                              dbg_bad_tlp_lcrc;
wire                              dbg_bad_tlp_seq_num;
wire                              dbg_bad_tlp_status;
wire                              dbg_dl_protocol_status;
wire                              dbg_fc_protocol_err_status;
wire                              dbg_mlfrmd_length;
wire                              dbg_mlfrmd_mps;
wire                              dbg_mlfrmd_tcvc;
wire                              dbg_mlfrmd_tlp_status;
wire                              dbg_mlfrmd_unrec_type;
wire                              dbg_poistlpstatus;
wire                              dbg_rcvr_overflow_status;
wire                              dbg_rply_rollover_status;
wire                              dbg_rply_timeout_status;
wire                              dbg_ur_no_bar_hit;
wire                              dbg_ur_pois_cfg_wr;
wire                              dbg_ur_status;
wire                              dbg_ur_unsup_msg;

reg [31:0]                        r_dbg_reg;
reg                               r_rst_dbg;


//Submodules
//artemis_pcie_interface #(
artemis_pcie_controller #(
  .DATA_FIFO_DEPTH                   (DATA_FIFO_DEPTH              ),
  .SERIAL_NUMBER                     (64'h000000000000C594         )
)api (
  .clk                               (clk                          ),
  //.rst                               (rst || !r_enable_pcie || !i_pcie_reset_n ),
  .rst                               (!r_enable_pcie || !i_pcie_reset_n ),

  .gtp_clk_p                         (i_clk_100mhz_gtp_p           ),
  .gtp_clk_n                         (i_clk_100mhz_gtp_n           ),

  .pci_exp_txp                       (o_pcie_phy_tx_p              ),
  .pci_exp_txn                       (o_pcie_phy_tx_n              ),
  .pci_exp_rxp                       (i_pcie_phy_rx_p              ),
  .pci_exp_rxn                       (i_pcie_phy_rx_n              ),


  // Transaction (TRN) Interface
  .user_lnk_up                       (user_lnk_up                  ),
  .clk_62p5                          (clk_62p5                     ),


  //User Interfaces
  .o_per_fifo_sel                    (w_per_fifo_sel               ),
  .o_mem_fifo_sel                    (w_mem_fifo_sel               ),
  .o_dma_fifo_sel                    (w_dma_fifo_sel               ),

  .i_usr_interrupt_stb               (w_usr_interrupt_stb          ),
  .i_usr_interrupt_value             (w_usr_interrupt_value        ),

  .o_data_size                       (w_data_size                  ),
  .o_data_address                    (w_data_address               ),
  .o_data_fifo_flg                   (w_data_fifo_flg              ),
  .o_data_read_flg                   (w_data_read_flg              ),
  .o_data_write_flg                  (w_data_write_flg             ),


  //Ingress FIFO
  .i_data_clk                        (clk                          ),
  .o_ingress_fifo_rdy                (w_fifo_ingress_rd_ready      ),
  .i_ingress_fifo_act                (w_fifo_ingress_rd_activate   ),
  .o_ingress_fifo_size               (w_fifo_ingress_rd_size       ),
  .i_ingress_fifo_stb                (w_fifo_ingress_rd_stb        ),
  .o_ingress_fifo_data               (w_fifo_ingress_rd_data       ),

  .o_egress_fifo_rdy                 (w_fifo_egress_wr_ready       ),
  .i_egress_fifo_act                 (w_fifo_egress_wr_activate    ),
  .o_egress_fifo_size                (w_fifo_egress_wr_size        ),
  .i_egress_fifo_stb                 (w_fifo_egress_wr_stb         ),
  .i_egress_fifo_data                (w_fifo_egress_wr_data        ),

  // Flow Control
  .fc_sel                            (fc_sel                       ),
  .fc_nph                            (fc_nph                       ),
  .fc_npd                            (fc_npd                       ),
  .fc_ph                             (fc_ph                        ),
  .fc_pd                             (fc_pd                        ),
  .fc_cplh                           (fc_cplh                      ),
  .fc_cpld                           (fc_cpld                      ),

  .o_bar_addr0                       (w_bar_addr0                  ),
  .o_bar_addr1                       (w_bar_addr1                  ),
  .o_bar_addr2                       (w_bar_addr2                  ),
  .o_bar_addr3                       (w_bar_addr3                  ),
  .o_bar_addr4                       (w_bar_addr4                  ),
  .o_bar_addr5                       (w_bar_addr5                  ),


  // Configuration: Power Management
  .cfg_turnoff_ok                    (cfg_turnoff_ok               ),
  .cfg_to_turnoff                    (cfg_to_turnoff               ),
  .cfg_pm_wake                       (cfg_pm_wake                  ),

  // System Interface
  .pcie_reset                        (pcie_reset                   ),
  .received_hot_reset                (received_hot_reset           ),
  .gtp_pll_lock_detect               (gtp_pll_lock_detect          ),
  .gtp_reset_done                    (gtp_reset_done               ),
  .pll_lock_detect                   (pll_lock_detect              ),

  .rx_elec_idle                      (rx_elec_idle                 ),
  .rx_equalizer_ctrl                 (r_rx_equalizer_ctrl          ),

  .tx_diff_ctrl                      (r_tx_diff_ctrl               ),
  .tx_pre_emphasis                   (r_tx_pre_emphasis            ),

  .cfg_ltssm_state                   (cfg_ltssm_state              ),

  .o_bar_hit                         (w_bar_hit                    ),
  .o_receive_axi_ready               (w_receive_axi_ready          ),


  .dbg_reg_detected_correctable      (dbg_reg_detected_correctable ),
  .dbg_reg_detected_fatal            (dbg_reg_detected_fatal       ),
  .dbg_reg_detected_non_fatal        (dbg_reg_detected_non_fatal   ),
  .dbg_reg_detected_unsupported      (dbg_reg_detected_unsupported ),

  .dbg_bad_dllp_status               (dbg_bad_dllp_status          ),
  .dbg_bad_tlp_lcrc                  (dbg_bad_tlp_lcrc             ),
  .dbg_bad_tlp_seq_num               (dbg_bad_tlp_seq_num          ),
  .dbg_bad_tlp_status                (dbg_bad_tlp_status           ),
  .dbg_dl_protocol_status            (dbg_dl_protocol_status       ),
  .dbg_fc_protocol_err_status        (dbg_fc_protocol_err_status   ),
  .dbg_mlfrmd_length                 (dbg_mlfrmd_length            ),
  .dbg_mlfrmd_mps                    (dbg_mlfrmd_mps               ),
  .dbg_mlfrmd_tcvc                   (dbg_mlfrmd_tcvc              ),
  .dbg_mlfrmd_tlp_status             (dbg_mlfrmd_tlp_status        ),
  .dbg_mlfrmd_unrec_type             (dbg_mlfrmd_unrec_type        ),
  .dbg_poistlpstatus                 (dbg_poistlpstatus            ),
  .dbg_rcvr_overflow_status          (dbg_rcvr_overflow_status     ),
  .dbg_rply_rollover_status          (dbg_rply_rollover_status     ),
  .dbg_rply_timeout_status           (dbg_rply_timeout_status      ),
  .dbg_ur_no_bar_hit                 (dbg_ur_no_bar_hit            ),
  .dbg_ur_pois_cfg_wr                (dbg_ur_pois_cfg_wr           ),
  .dbg_ur_status                     (dbg_ur_status                ),
  .dbg_ur_unsup_msg                  (dbg_ur_unsup_msg             ),

  //Extra Info
  .o_cfg_read_exec                   (w_cfg_read_exec              ),
  .o_cfg_sm_state                    (w_cfg_sm_state               ),
  .o_sm_state                        (w_sm_state                   ),

  .cfg_pcie_link_state               (cfg_pcie_link_state          ),
  .cfg_bus_number                    (cfg_bus_number               ),
  .cfg_device_number                 (cfg_device_number            ),
  .cfg_function_number               (cfg_function_number          ),

  .cfg_status                        (cfg_status                   ),
  .cfg_command                       (cfg_command                  ),
  .cfg_dstatus                       (cfg_dstatus                  ),
  .cfg_dcommand                      (cfg_dcommand                 ),
  .cfg_lstatus                       (cfg_lstatus                  ),
  .cfg_lcommand                      (cfg_lcommand                 ),

  // Configuration: Error
  .cfg_err_ur                        (cfg_err_ur                   ),
  .cfg_err_cor                       (cfg_err_cor                  ),
  .cfg_err_ecrc                      (cfg_err_ecrc                 ),
  .cfg_err_cpl_timeout               (cfg_err_cpl_timeout          ),
  .cfg_err_cpl_abort                 (cfg_err_cpl_abort            ),
  .cfg_err_posted                    (cfg_err_posted               ),
  .cfg_err_locked                    (cfg_err_locked               ),
  .cfg_err_tlp_cpl_header            (cfg_err_tlp_cpl_header       ),
  .cfg_err_cpl_rdy                   (cfg_err_cpl_rdy              ),

  //Debug Info
  .o_ingress_count                   (w_ingress_count              ),
  .o_ingress_state                   (w_ingress_state              ),
  .o_ingress_ri_count                (w_ingress_ri_count           ),
  .o_ingress_ci_count                (w_ingress_ci_count           ),
  .o_ingress_addr                    (w_ingress_addr               )
);

adapter_dpb_ppfifo #(
  .MEM_DEPTH                          (DATA_FIFO_DEPTH             ),
  .DATA_WIDTH                         (32                          )
)dpb_bridge (
  .clk                                (clk                         ),
  .rst                                (rst                         ),
  .i_ppfifo_2_mem_en                  (r_ppfifo_2_mem_en           ),
  .i_mem_2_ppfifo_stb                 (r_mem_2_ppfifo_stb          ),
  .i_cancel_write_stb                 (r_cancel_write_stb          ),
  .o_num_reads                        (w_num_reads                 ),
  .o_idle                             (w_idle                      ),

  .i_bram_we                          (r_lcl_mem_we                ),
  .i_bram_addr                        (w_lcl_mem_addr              ),
  .i_bram_din                         (r_lcl_mem_din               ),
  .o_bram_dout                        (w_lcl_mem_dout              ),
  .o_bram_valid                       (w_lcl_mem_valid             ),

  .ppfifo_clk                         (clk                         ),

  .i_write_ready                      (w_fifo_egress_wr_ready      ),
  .o_write_activate                   (w_fifo_egress_wr_activate   ),
  .i_write_size                       (w_fifo_egress_wr_size       ),
  .o_write_stb                        (w_fifo_egress_wr_stb        ),
  .o_write_data                       (w_fifo_egress_wr_data       ),

  .i_read_ready                       (w_fifo_ingress_rd_ready     ),
  .o_read_activate                    (w_fifo_ingress_rd_activate  ),
  .i_read_size                        (w_fifo_ingress_rd_size      ),
  .i_read_data                        (w_fifo_ingress_rd_data      ),
  .o_read_stb                         (w_fifo_ingress_rd_stb       )
);

cross_clock_strobe clk_stb (
  .rst                                (rst                         ),
  .in_clk                             (clk                         ),
  .in_stb                             (r_1sec_stb_100mhz           ),

  .out_clk                            (clk_62p5                    ),
  .out_stb                            (w_1sec_stb_65mhz            )
);

//Asynchronous Logic
assign  fc_sel                 = 3'h0;

//assign  cfg_dwaddr             = 10'h0;
//assign  cfg_rd_en              = 1'b0;

assign  cfg_err_ur             = 0;
assign  cfg_err_cor            = 0;
assign  cfg_err_ecrc           = 0;
assign  cfg_err_cpl_timeout    = 0;
assign  cfg_err_cpl_abort      = 0;
assign  cfg_err_posted         = 0;
assign  cfg_err_locked         = 0;
assign  cfg_err_tlp_cpl_header = 0;

//assign  cfg_interrupt          = 0;
//assign  cfg_interrupt_assert   = 0;
//assign  cfg_interrupt_di       = 0;

//assign  cfg_turnoff_ok         = 0;
assign  cfg_pm_wake             = 0;
assign  o_pcie_wake_n           = 1;
assign  w_lcl_mem_en            = ((i_wbs_adr >= `LOCAL_BUFFER_OFFSET) &&
                                   (i_wbs_adr < (`LOCAL_BUFFER_OFFSET + DATA_BUFFER_SIZE)));

assign  w_lcl_mem_addr          = w_lcl_mem_en ? (i_wbs_adr - `LOCAL_BUFFER_OFFSET) : 0;
//assign  !i_pcie_reset_n          = r_enable_ext_reset ? !i_pcie_reset_n : r_manual_pcie_reset;
//assign  !i_pcie_reset_n          = i_pcie_reset_n;
assign  o_62p5_clk              = clk_62p5;

assign  o_debug_data            = { 26'h0,
                                    pll_lock_detect,
                                    pcie_reset,
                                    user_lnk_up,
                                    cfg_ltssm_state};

assign  w_usr_interrupt_stb     = 0;
assign  w_usr_interrupt_value   = 0;
//Synchronous Logic

always @ (posedge clk_62p5) begin
  if (!i_pcie_reset_n) begin
    r_clock_1_sec                <= 0;
    r_clock_count                <= 0;
    cfg_turnoff_ok               <= 0;
    trn_pending                  <= 0;
    r_dbg_reg                    <= 0;
  end
  else begin
    r_clock_count   <=  r_clock_count + 1;
    if (w_1sec_stb_65mhz) begin
      r_clock_1_sec   <=  r_clock_count;
      r_clock_count   <=  0;
    end

    //Power Controller
    if (cfg_to_turnoff && !trn_pending) begin
      cfg_turnoff_ok    <=  1;
    end
    else begin
      cfg_turnoff_ok              <=  0;
    end

    if(dbg_reg_detected_correctable) begin
        r_dbg_reg[`DBG_DTCT_CRCT]            <= 1;
    end
    if(dbg_reg_detected_fatal) begin
        r_dbg_reg[`DBG_DTCT_FATL]            <= 1;
    end
    if(dbg_reg_detected_non_fatal) begin
        r_dbg_reg[`DBG_DTCT_NFTL]            <= 1;
    end
    if(dbg_reg_detected_unsupported) begin
        r_dbg_reg[`DBG_DTCT_UNSP]            <= 1;
    end

    if(dbg_bad_dllp_status) begin
        r_dbg_reg[`DBG_DLLP_STS]             <= 1;
    end
    if(dbg_bad_tlp_lcrc) begin
        r_dbg_reg[`DBG_BD_TLP_LCRC]          <= 1;
    end
    if(dbg_bad_tlp_seq_num) begin
        r_dbg_reg[`DBG_BD_TLP_SQNM]          <= 1;
    end
    if(dbg_bad_tlp_status) begin
        r_dbg_reg[`DBG_BD_TLP_STS]           <= 1;
    end
    if(dbg_dl_protocol_status) begin
        r_dbg_reg[`DBG_DL_PTCL_STS]          <= 1;
    end
    if(dbg_fc_protocol_err_status) begin
        r_dbg_reg[`DBG_FC_PTCL_STS]          <= 1;
    end
    if(dbg_mlfrmd_length) begin
        r_dbg_reg[`DBG_MLFM_LEN]             <= 1;
    end
    if(dbg_mlfrmd_mps) begin
        r_dbg_reg[`DBG_MLFM_MPS]             <= 1;
    end
    if(dbg_mlfrmd_tcvc) begin
        r_dbg_reg[`DBG_MLFM_TCVC]            <= 1;
    end
    if(dbg_mlfrmd_tlp_status) begin
        r_dbg_reg[`DBG_MLFM_TLP_STS]         <= 1;
    end
    if(dbg_mlfrmd_unrec_type) begin
        r_dbg_reg[`DBG_MLFM_TLP_UNREC]       <= 1;
    end
    if(dbg_poistlpstatus) begin
        r_dbg_reg[`DBG_PLP_STS]              <= 1;
    end
    if(dbg_rcvr_overflow_status) begin
        r_dbg_reg[`DBG_RCVR_OVFL_STS]        <= 1;
    end
    if(dbg_rply_rollover_status) begin
        r_dbg_reg[`DBG_RCVR_RLVR_STS]        <= 1;
    end
    if(dbg_rply_timeout_status) begin
        r_dbg_reg[`DBG_RCVR_TMT_STS]         <= 1;
    end
    if(dbg_ur_no_bar_hit) begin
        r_dbg_reg[`DBG_UR_NO_BAR]            <= 1;
    end
    if(dbg_ur_pois_cfg_wr) begin
        r_dbg_reg[`DBG_UR_POIS]              <= 1;
    end
    if(dbg_ur_status) begin
        r_dbg_reg[`DBG_UR_STS]               <= 1;
    end
    if(dbg_ur_unsup_msg) begin
        r_dbg_reg[`DBG_UR_UNSUP_MSG]         <= 1;
    end
    if (r_rst_dbg) begin
      r_dbg_reg                              <= 0;
    end
  end
end


always @ (posedge clk) begin

  //Deassert Strobes
  r_mem_2_ppfifo_stb            <=  0;
  r_cancel_write_stb            <=  0;
  r_lcl_mem_we                  <=  0;
  r_1sec_stb_100mhz             <=  0;

  //THis might need to be moved into the 62.5MHz clock
  //r_cfg_trn_pending             <=  0;
  r_irq_stb                     <=  0;

  if (rst) begin
    o_wbs_dat                   <=  32'h0;
    o_wbs_ack                   <=  0;
    o_wbs_int                   <=  0;
    r_ppfifo_2_mem_en           <=  1;
    r_enable_pcie               <=  1;
    //r_enable_ext_reset          <=  1;
    //r_manual_pcie_reset         <=  0;

    r_lcl_mem_din               <=  0;
    r_host_clock_count          <=  0;

    r_rx_equalizer_ctrl         <=  2'b11;
    r_tx_diff_ctrl              <=  4'b1001;
    r_tx_pre_emphasis           <=  3'b00;

    r_bar_hit_temp              <=  0;
    r_rst_dbg                   <=  0;
  end
  else begin
    if (r_dbg_reg == 0) begin
      r_rst_dbg                 <=  0;
    end
    if ((r_bar_hit_temp == 0) && (w_bar_hit != 0)) begin
      r_bar_hit_temp           <= w_bar_hit;
    end
    //when the master acks our ack, then put our ack down
    if (o_wbs_ack && ~i_wbs_stb)begin
      if (i_wbs_adr == DBG_FLAGS) begin
        r_rst_dbg               <=  1;
      end
      o_wbs_ack <= 0;
    end

    if (i_wbs_stb && i_wbs_cyc) begin
      //master is requesting somethign
      if (!o_wbs_ack) begin
        if (i_wbs_we) begin
          //write request
          case (i_wbs_adr)
            CONTROL: begin
              $display("ADDR: %h user wrote %h", i_wbs_adr, i_wbs_dat);
              r_enable_pcie         <=  i_wbs_dat[`CTRL_BIT_ENABLE];
              r_mem_2_ppfifo_stb    <=  i_wbs_dat[`CTRL_BIT_SEND_CONTROL_BLOCK];
              r_cancel_write_stb    <=  i_wbs_dat[`CTRL_BIT_CANCEL_SEND_BLOCK];
              r_ppfifo_2_mem_en     <=  i_wbs_dat[`CTRL_BIT_ENABLE_LOCAL_READ];
              //r_reset_dbg_regs      <=  i_wbs_dat[`CTRL_BIT_RESET_DBG_REGS];
              //r_enable_ext_reset    <=  i_wbs_dat[`CTRL_BIT_ENABLE_EXT_RESET];
              //r_manual_pcie_reset   <=  i_wbs_dat[`CTRL_BIT_MANUAL_USER_RESET];
              //r_read_bar_addr_stb_a <=  i_wbs_dat[`CTRL_BIT_READ_BAR_ADDR_STB];
              r_irq_stb             <=  i_wbs_dat[`CTRL_BIT_SEND_IRQ];

            end
            TX_DIFF_CTRL: begin
              r_tx_diff_ctrl      <=  i_wbs_dat[3:0];
            end
            TX_DIFF_CTRL: begin
              r_tx_pre_emphasis   <=  i_wbs_dat[2:0];
            end
            RX_EQUALIZER_CTRL: begin
              r_rx_equalizer_ctrl <=  i_wbs_dat[1:0];
            end
            default: begin
              if (w_lcl_mem_en) begin
                r_lcl_mem_we                          <=  1;
                r_lcl_mem_din                         <=  i_wbs_dat;
              end
            end
          endcase
          o_wbs_ack <= 1;
        end
        else begin
          //read request
          case (i_wbs_adr)
            CONTROL: begin
              o_wbs_dat                               <=  0;
              o_wbs_dat[`CTRL_BIT_ENABLE_LOCAL_READ]  <=  r_ppfifo_2_mem_en;
              o_wbs_dat[`CTRL_BIT_ENABLE]             <=  r_enable_pcie;
              //o_wbs_dat[`CTRL_BIT_ENABLE_EXT_RESET]   <=  r_enable_ext_reset;
              //o_wbs_dat[`CTRL_BIT_MANUAL_USER_RESET]  <=  r_manual_pcie_reset;
            end
            STATUS: begin
              o_wbs_dat                               <=  0;
              o_wbs_dat[`STS_BIT_PCIE_RESET]          <=  pcie_reset;
              o_wbs_dat[`STS_BIT_LINKUP]              <=  user_lnk_up;
              o_wbs_dat[`STS_BIT_RECEIVED_HOT_RESET]  <=  received_hot_reset;
              o_wbs_dat[`STS_BITS_PCIE_LINK_STATE]    <=  cfg_pcie_link_state;
              o_wbs_dat[`STS_BITS_PCIE_BUS_NUM]       <=  cfg_bus_number;
              o_wbs_dat[`STS_BITS_PCIE_DEV_NUM]       <=  cfg_device_number;
              o_wbs_dat[`STS_BITS_PCIE_FUNC_NUM]      <=  cfg_function_number;
              o_wbs_dat[`STS_BIT_GTP_PLL_LOCK_DETECT] <=  gtp_pll_lock_detect;
              o_wbs_dat[`STS_BIT_PLL_LOCK_DETECT]     <=  pll_lock_detect;
              o_wbs_dat[`STS_BIT_GTP_RESET_DONE]      <=  gtp_reset_done;
              o_wbs_dat[`STS_BIT_RX_ELEC_IDLE]        <=  rx_elec_idle;
              o_wbs_dat[`STS_BIT_CFG_TO_TURNOFF]      <=  cfg_to_turnoff;
              o_wbs_dat[`STS_BIT_PCIE_EXT_RESET]      <=  !i_pcie_reset_n;
              o_wbs_dat[`STS_BIT_AXI_RECEIVE_READY]   <=  w_receive_axi_ready;
            end
            NUM_BLOCK_READ: begin
              o_wbs_dat <= w_num_reads;
            end
            LOCAL_BUFFER_SIZE: begin
              o_wbs_dat <= DATA_BUFFER_SIZE;
            end
            PCIE_CLOCK_CNT: begin
              o_wbs_dat <=  r_clock_1_sec;
            end
            TEST_CLOCK: begin
              o_wbs_dat       <=  r_clock_count;
            end
            TX_DIFF_CTRL: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[3:0]  <=  r_tx_diff_ctrl;
            end
            TX_PRE_EMPH: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[3:0]  <=  r_tx_pre_emphasis;
            end
            RX_EQUALIZER_CTRL: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[1:0]  <=  r_rx_equalizer_ctrl;
            end
            LTSSM_STATE: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[4:0]  <=  cfg_ltssm_state;
            end
            DBG_DATA: begin
              o_wbs_dat       <=  0;
              //o_wbs_dat[`DBG_CORRECTABLE ] <=  dbg_correctable;
              //o_wbs_dat[`DBG_FATAL       ] <=  dbg_fatal;
              //o_wbs_dat[`DBG_NON_FATAL   ] <=  dbg_non_fatal;
              //o_wbs_dat[`DBG_UNSUPPORTED ] <=  dbg_unsupported;
            end
            USR_IF_FLAGS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[`USR_IF_BIT_PER_BUS_SEL ]  <=  w_per_fifo_sel;
              o_wbs_dat[`USR_IF_BIT_MEM_BUS_SEL ]  <=  w_mem_fifo_sel;
              o_wbs_dat[`USR_IF_BIT_DMA_BUS_SEL ]  <=  w_dma_fifo_sel;
              o_wbs_dat[`USR_IF_BIT_WR_FLAG     ]  <=  w_data_write_flg;
              o_wbs_dat[`USR_IF_BIT_RD_FLAG     ]  <=  w_data_read_flg;
              o_wbs_dat[`USR_IF_BIT_FIFO_FLAG   ]  <=  w_data_fifo_flg;
            end
            USR_IF_SIZE: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=  w_data_size;
            end
            USR_IF_ADDRESS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat       <=  w_data_address;
            end

/*
            CONFIG_COMMAND: begin
              o_wbs_dat       <=  0;
              o_wbs_dat                       <=  {16'h0000, cfg_command};
            end
            CONFIG_STATUS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat                       <=  {16'h0000, cfg_status};
            end
            CONFIG_DSTATUS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat                       <=  {16'h0000, cfg_dstatus};
            end
            CONFIG_DCOMMAND: begin
              o_wbs_dat       <=  0;
              o_wbs_dat                       <=  {16'h0000, cfg_dcommand};
            end
            CONFIG_LSTATUS: begin
              o_wbs_dat       <=  0;
              o_wbs_dat                       <=  {16'h0000, cfg_lstatus};
            end
            CONFIG_LCOMMAND: begin
              o_wbs_dat       <=  0;
              o_wbs_dat                       <=  {16'h0000, cfg_lcommand};
            end
*/
            DBG_FLAGS: begin
              o_wbs_dat                         <=  r_dbg_reg;
            end
            BAR_SELECT: begin
              //o_wbs_dat                         <=  {24'h0, r_unrecognized_bar};
              o_wbs_dat                         <=  {25'h0, r_bar_hit_temp};
              r_bar_hit_temp                    <=  0;
            end
            BAR_ADDR0: begin
              o_wbs_dat                         <=  w_bar_addr0;
            end
            BAR_ADDR1: begin
              o_wbs_dat                         <=  w_bar_addr1;
            end
            BAR_ADDR2: begin
              o_wbs_dat                         <=  w_bar_addr2;
            end
            BAR_ADDR3: begin
              o_wbs_dat                         <=  w_bar_addr3;
            end
            BAR_ADDR4: begin
              o_wbs_dat                         <=  w_bar_addr4;
            end
            BAR_ADDR5: begin
              o_wbs_dat                         <=  w_bar_addr5;
            end
            CFG_READ_EXEC: begin
              o_wbs_dat                         <=  {24'h00, w_cfg_read_exec};
            end
            CFG_SM_STATE: begin
              o_wbs_dat                         <=  {28'h00, w_cfg_sm_state};
            end
            CTR_SM_STATE: begin
              o_wbs_dat                         <=  {28'h00, w_sm_state};
            end
            INGRESS_COUNT: begin
              o_wbs_dat                         <=  {24'h00, w_ingress_count};
            end
            INGRESS_STATE: begin
              o_wbs_dat                         <=  {28'h00, w_ingress_state};
            end
            INGRESS_RI_COUNT: begin
              o_wbs_dat                         <=  {24'h00, w_ingress_ri_count};
            end
            INGRESS_CI_COUNT: begin
              o_wbs_dat                         <=  {24'h00, w_ingress_ci_count};
            end
            INGRESS_ADDR: begin
              o_wbs_dat                         <=  w_ingress_addr;
            end
            default: begin
              if (w_lcl_mem_en) begin
                o_wbs_dat                       <=  w_lcl_mem_dout;
              end
            end
          endcase
          if (w_lcl_mem_valid) begin
            o_wbs_ack <= 1;
          end
        end
      end
    end
    if (r_host_clock_count < `CLOCK_RATE) begin
      r_host_clock_count                        <= r_host_clock_count + 1;
    end
    else begin
      r_host_clock_count                        <= 0;
      r_1sec_stb_100mhz                         <= 1;
    end

  end
end

endmodule
