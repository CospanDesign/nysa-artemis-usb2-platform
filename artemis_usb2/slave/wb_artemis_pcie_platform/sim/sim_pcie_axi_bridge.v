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
 * Author: Dave McCoy (dave.mccoy@cospandesign.com)
 * Description:
 *  Simulation of the PCIE Interface, used primarily to test out
 *    HDL Core
 * Changes:
 */



module sim_pcie_axi_bridge #(
  parameter PCIE_BUS_NUM                              = 8'h55,
  parameter PCIE_DEV_NUM                              = 5'hA,
  parameter PCIE_FUN_NUM                              = 3'h2,

  parameter USR_CLK_DIVIDE                            = 4,

  parameter   [6:0] VC0_TOTAL_CREDITS_PH              = 32,
  parameter  [10:0] VC0_TOTAL_CREDITS_PD              = 211,
  parameter   [6:0] VC0_TOTAL_CREDITS_NPH             = 8,
  parameter   [6:0] VC0_TOTAL_CREDITS_CH              = 40,
  //parameter   [6:0] VC0_TOTAL_CREDITS_CH              = 9,
  parameter  [10:0] VC0_TOTAL_CREDITS_CD              = 211
)(

  // PCI Express Fabric Interface
  output                    pci_exp_txp,  //Not Applicable
  output                    pci_exp_txn,  //Not Applicable
  input                     pci_exp_rxp,  //Not Applicable
  input                     pci_exp_rxn,  //Not Applicable

  // Transaction (TRN) Interface
  output  reg               user_lnk_up,  //Finished

  // Tx
  output  reg               s_axis_tx_tready, //SIM: Not Finished
  input       [31:0]        s_axis_tx_tdata,  //SIM: Not Finished
  input       [3:0]         s_axis_tx_tkeep,  //SIM: Not Finished
  input       [3:0]         s_axis_tx_tuser,  //SIM: Not Finished
  input                     s_axis_tx_tlast,  //SIM: Not Finished
  input                     s_axis_tx_tvalid, //SIM: Not Finished

  output  reg [5:0]         tx_buf_av,
  output  reg               tx_err_drop,
  input                     tx_cfg_gnt,
  output  reg               tx_cfg_req,

  output  reg               user_enable_comm, //SIM: Not Finished

  // Rx
  output  reg [31:0]        m_axis_rx_tdata = 32'h00000000,
  output  reg [3:0]         m_axis_rx_tkeep = 4'b1111,
  output  reg               m_axis_rx_tlast = 1'b0,
  output  reg               m_axis_rx_tvalid = 1'b0,
  input                     m_axis_rx_tready,
  output      [21:0]        m_axis_rx_tuser,
  input                     rx_np_ok,         //SIM: Not Finished

  // Flow Control
  input       [2:0]         fc_sel,
  output      [7:0]         fc_nph,
  output      [11:0]        fc_npd,
  output      [7:0]         fc_ph,
  output      [11:0]        fc_pd,
  output      [7:0]         fc_cplh,
  output      [11:0]        fc_cpld,

  // Host (CFG) Interface
  output  reg [31:0]        cfg_do,           //SIM: Finished
  output  reg               cfg_rd_wr_done,   //SIM: Finished
  input       [9:0]         cfg_dwaddr,       //SIM: Finished
  input                     cfg_rd_en,        //SIM: Finished

  // Configuration: Error
  input                     cfg_err_ur,
  input                     cfg_err_cor,
  input                     cfg_err_ecrc,
  input                     cfg_err_cpl_timeout,
  input                     cfg_err_cpl_abort,
  input                     cfg_err_posted,
  input                     cfg_err_locked,
  input      [47:0]         cfg_err_tlp_cpl_header,
  output                    cfg_err_cpl_rdy,

  // Conifguration: Interrupt
  input                     cfg_interrupt,
  output  reg               cfg_interrupt_rdy = 1,
  input                     cfg_interrupt_assert,
  output  reg [7:0]         cfg_interrupt_do  = 0,
  input       [7:0]         cfg_interrupt_di,
  output  reg [2:0]         cfg_interrupt_mmenable = 0,
  output  reg               cfg_interrupt_msienable = 0,

  // Configuration: Power Management
  input                     cfg_turnoff_ok,       //Not Applicable
  output                    cfg_to_turnoff,       //Not Applicable
  input                     cfg_pm_wake,          //Not Applicable

  //Core Controller
  // Configuration: System/Status
  output      [2:0]         cfg_pcie_link_state,  //Not Applicable
  input                     cfg_trn_pending,
  input       [63:0]        cfg_dsn,
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
  input                     sys_clk_p,
  input                     sys_clk_n,
  input                     sys_reset,
  output                    user_clk_out,
  output                    user_reset_out,
  output                    received_hot_reset,

  // Not Finished
  output                    pll_lock_detect,
  output                    gtp_pll_lock_detect,
  output                    gtp_reset_done,
  output      [4:0]         cfg_ltssm_state,
  input       [1:0]         rx_equalizer_ctrl,
  input       [3:0]         tx_diff_ctrl,
  input       [2:0]         tx_pre_emphasis,
  output      [6:0]         o_bar_hit,

  output                    dbg_reg_detected_correctable, //Not Applicable
  output                    dbg_reg_detected_fatal,       //Not Applicable
  output                    dbg_reg_detected_non_fatal,   //Not Applicable
  output                    dbg_reg_detected_unsupported, //Not Applicable

  output                    dbg_bad_dllp_status,          //Not Applicable
  output                    dbg_bad_tlp_lcrc,             //Not Applicable
  output                    dbg_bad_tlp_seq_num,          //Not Applicable
  output                    dbg_bad_tlp_status,           //Not Applicable
  output                    dbg_dl_protocol_status,       //Not Applicable
  output                    dbg_fc_protocol_err_status,   //Not Applicable
  output                    dbg_mlfrmd_length,            //Not Applicable
  output                    dbg_mlfrmd_mps,               //Not Applicable
  output                    dbg_mlfrmd_tcvc,              //Not Applicable
  output                    dbg_mlfrmd_tlp_status,        //Not Applicable
  output                    dbg_mlfrmd_unrec_type,        //Not Applicable
  output                    dbg_poistlpstatus,            //Not Applicable
  output                    dbg_rcvr_overflow_status,     //Not Applicable
  output                    dbg_rply_rollover_status,     //Not Applicable
  output                    dbg_rply_timeout_status,      //Not Applicable
  output                    dbg_ur_no_bar_hit,            //Not Applicable
  output                    dbg_ur_pois_cfg_wr,           //Not Applicable
  output                    dbg_ur_status,                //Not Applicable
  output                    dbg_ur_unsup_msg,             //Not Applicable

  output                    rx_elec_idle
);

assign                pll_lock_detect = 1'b1;

//Local Parameters
localparam            RESET_OUT_TIMEOUT   = 32'h00000010;
localparam            LINKUP_TIMEOUT      = 32'h00000010;

localparam            CONTROL_PACKET_SIZE = 128;
localparam            DATA_PACKET_SIZE    = 512;
localparam            F2_PACKET_SIZE      = 0;
localparam            F3_PACKET_SIZE      = 0;
localparam            F4_PACKET_SIZE      = 0;
localparam            F5_PACKET_SIZE      = 0;
localparam            F6_PACKET_SIZE      = 0;
localparam            F7_PACKET_SIZE      = 0;



localparam            CONTROL_FUNCTION_ID = 0;
localparam            DATA_FUNCTION_ID    = 1;
localparam            F2_ID               = 2;
localparam            F3_ID               = 3;
localparam            F4_ID               = 4;
localparam            F5_ID               = 5;
localparam            F6_ID               = 6;
localparam            F7_ID               = 7;


//Registers/Wires
reg           clk = 0;
reg   [23:0]  r_usr_clk_count;
reg           rst = 0;
reg   [23:0]  r_usr_rst_count;

reg   [23:0]  r_linkup_timeout;

reg   [23:0]  r_mcount;
reg   [23:0]  r_scount;
wire  [23:0]  w_func_size_map [0:7];

wire  [23:0]  w_func_size;

//Submodules
//Asynchronous Logic
assign  pcie_exp_txp              = 0;
assign  pcie_exp_txn              = 0;

//assign  user_clk_out              = clk;
//assign  user_reset_out            = rst;

assign  w_func_size_map[CONTROL_FUNCTION_ID ] = CONTROL_PACKET_SIZE;
assign  w_func_size_map[DATA_FUNCTION_ID    ] = DATA_PACKET_SIZE;
assign  w_func_size_map[F2_ID               ] = F2_PACKET_SIZE;
assign  w_func_size_map[F3_ID               ] = F3_PACKET_SIZE;
assign  w_func_size_map[F4_ID               ] = F4_PACKET_SIZE;
assign  w_func_size_map[F5_ID               ] = F5_PACKET_SIZE;
assign  w_func_size_map[F6_ID               ] = F6_PACKET_SIZE;
assign  w_func_size_map[F7_ID               ] = F7_PACKET_SIZE;

assign  w_func_size               = w_func_size_map[cfg_function_number];

//TODO
assign  received_hot_reset        = 0;

//  input       [2:0]         fc_sel,
assign  fc_nph      = VC0_TOTAL_CREDITS_NPH;
assign  fc_npd      = 10;
assign  fc_ph       = VC0_TOTAL_CREDITS_PH;
assign  fc_pd       = 100;
assign  fc_cplh     = VC0_TOTAL_CREDITS_CH;
assign  fc_cpld     = VC0_TOTAL_CREDITS_CD;



assign  cfg_err_cpl_rdy           = 0;

//assign  cfg_interrupt_rdy         = 0;
//assign  cfg_interrupt_do          = 0;
//assign  cfg_interrupt_mmenable    = 0;
//assign  cfg_interrupt_msienable   = 0;

assign  cfg_to_turnoff            = 0;

assign  cfg_pcie_link_state       = 0;

assign  cfg_status                = 0;
assign  cfg_command               = 0;
assign  cfg_dstatus               = 0;
assign  cfg_dcommand              = 0;
assign  cfg_lstatus               = 0;
assign  cfg_lcommand              = 0;

//Synchronous Logic
//Generate clock
always @ (posedge sys_clk_p) begin
  if (sys_reset) begin
    clk               <=  0;
    r_usr_clk_count   <=  0;
  end
  else begin
    if (r_usr_clk_count < USR_CLK_DIVIDE) begin
      r_usr_clk_count <=  r_usr_clk_count + 1;
    end
    else begin
      clk             <=  ~clk;
    end
  end
end

//Generate Reset Pulse
always @ (posedge sys_clk_p or posedge sys_reset) begin
  if (sys_reset) begin
    rst               <=  1;
    r_usr_rst_count   <=  0;
  end
  else begin
    if (r_usr_rst_count < RESET_OUT_TIMEOUT) begin
      r_usr_rst_count <=  r_usr_rst_count + 1;
    end
    else begin
      rst             <=  0;
    end
  end
end

//Send user a linkup signal
always @ (posedge clk) begin
  if (rst) begin
    r_linkup_timeout    <=  0;
    user_lnk_up         <=  0;
  end
  else begin
    if (r_linkup_timeout < LINKUP_TIMEOUT) begin
      r_linkup_timeout  <=  r_linkup_timeout + 1;
    end
    else begin
      user_lnk_up       <=  1;
    end
  end
end


//Data From PCIE to Core Ggenerator
reg [3:0] dm_state;

localparam  IDLE    = 0;
localparam  READY   = 1;
localparam  WRITE   = 2;
localparam  READ    = 3;


assign  o_bar_hit = 7'h01;

assign  m_axis_rx_tuser   =  {13'h0,
                              o_bar_hit,
                              m_axis_rx_tvalid,
                              1'b0};

assign  cfg_bus_number      = PCIE_BUS_NUM;
assign  cfg_function_number = PCIE_FUN_NUM;
assign  cfg_device_number   = PCIE_DEV_NUM;

always @ (posedge clk) begin
  m_axis_rx_tkeep   <=  4'b1111;
end
/*
always @ (posedge clk) begin
  m_axis_rx_tlast     <=  0;
  m_axis_rx_tvalid    <=  0;

  if (rst) begin
    m_axis_rx_tdata   <=  0;
    dm_state          <=  IDLE;

    m_axis_rx_tkeep   <=  4'b1111;

    r_mcount          <=  0;
  end
  else begin
    //m_axis_rx_tready
    //rx_np_ok
    case (dm_state)
      IDLE: begin
        r_mcount        <=  0;
        dm_state        <=  READY;
        m_axis_rx_tdata <=  0;
      end
      READY: begin
        if (m_axis_rx_tready) begin
          dm_state          <=  WRITE;
        end
      end
      WRITE: begin
        if (m_axis_rx_tvalid) begin
          m_axis_rx_tdata   <=  m_axis_rx_tdata + 1;
        end
        if (r_mcount < w_func_size_map[cfg_function_number]) begin
          m_axis_rx_tvalid  <=  1;
          if (r_mcount >= (w_func_size_map[cfg_function_number] - 1)) begin
            m_axis_rx_tlast <=  1;
          end
          r_mcount          <=  r_mcount + 1;
        end
        else begin
          dm_state          <=  IDLE;
        end
      end
      default: begin
      end
    endcase
  end
end
*/

//Linkup
reg prev_user_lnk_up;
reg [3:0] linkup_count;

always @ (posedge clk) begin
  user_enable_comm    <=  0;
  if (rst || !user_lnk_up) begin
    linkup_count      <=  0;
  end
  else begin
    if (linkup_count < 4'hF) begin
      linkup_count    <=  linkup_count + 1;
    end

    if (linkup_count == 4'hE) begin
      user_enable_comm  <=  1;
    end
  end
end

//Configuration Read
always @ (posedge clk) begin
  cfg_rd_wr_done    <=  0;
  if (rst) begin
    cfg_do          <=  0;
  end
  else begin
    if (cfg_rd_en) begin
      cfg_rd_wr_done  <=  1;
      case (cfg_dwaddr)
        4: cfg_do           <=  32'h00000200;
        5: cfg_do           <=  32'h00001000;
        6: cfg_do           <=  32'h00000000;
        7: cfg_do           <=  32'h00000000;
        8: cfg_do           <=  32'h00000000;
        9: cfg_do           <=  32'h00000000;
        default: cfg_do     <=  32'hFFFFFFFF;
      endcase
    end
  end
end





//AXI Data D2H
//Data From Core to PCIE Reader
/*
reg [3:0] ds_state;
always @ (posedge clk) begin
  s_axis_tx_tready  <=  0;
  if (rst) begin
    //s_axis_tx_tdata
    //s_axis_tx_tkeep
    //s_axis_tx_tuser
    //s_axis_tx_tlast
    //s_axis_tx_tvalid

    tx_buf_av       <=  0;
    tx_err_drop     <=  0;
    //tx_cfg_gnt      <=  0;
    tx_cfg_req      <=  0;

    ds_state        <=  IDLE;
    r_scount        <=  0;
  end
  else begin
    case (ds_state)
      IDLE: begin
        r_scount    <=  0;
        ds_state    <=  READ;
      end
      READ: begin
        if (s_axis_tx_tvalid && (r_scount < w_func_size_map[cfg_function_number])) begin
          s_axis_tx_tready    <=  1;
        end
        else begin
          ds_state  <=  IDLE;
        end
      end
      default: begin
      end
    endcase
  end
end
*/

endmodule
