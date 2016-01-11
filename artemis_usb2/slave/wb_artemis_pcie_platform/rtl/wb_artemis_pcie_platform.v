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

`define CTRL_BIT_ENABLE             0
`define CTRL_BIT_SEND_CONTROL_BLOCK 1
`define CTRL_BIT_CANCEL_SEND_BLOCK  2
`define CTRL_BIT_ENABLE_LOCAL_READ  3

`define STS_BIT_PCIE_RESET          0
`define STS_BIT_LINKUP              1
`define STS_BIT_RECEIVED_HOT_RESET  2
`define STS_BITS_PCIE_LINK_STATE    6:4
`define STS_BITS_PCIE_BUS_NUM       15:8
`define STS_BITS_PCIE_DEV_NUM       19:16
`define STS_BITS_PCIE_FUNC_NUM      22:20
`define STS_BITS_LOCAL_MEM_IDLE     24
`define STS_BIT_GTP_PLL_LOCK_DETECT 25
`define STS_BIT_PLL_LOCK_DETECT     26
`define STS_BIT_GTP_RESET_DONE      27
`define STS_BIT_RX_ELEC_IDLE        28


`define LOCAL_BUFFER_OFFSET         24'h000100


module wb_artemis_pcie_platform #(
  parameter           CONTROL_FIFO_DEPTH = 7,
  parameter           DATA_FIFO_DEPTH = 9
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
  output              o_pcie_wake_n
);

//Local Parameters
localparam    CONTROL_BUFFER_SIZE = 2 ** CONTROL_FIFO_DEPTH;

localparam    CONTROL             = 0;
localparam    STATUS              = 1;
localparam    NUM_BLOCK_READ      = 2;
localparam    LOCAL_BUFFER_SIZE   = 3;
localparam    PCIE_CLOCK_CNT      = 4;
localparam    TEST_CLOCK          = 5;
localparam    TX_DIFF_CTRL        = 6;
localparam    RX_EQUALIZER_CTRL   = 7;
localparam    LTSSM_STATE         = 8;

//Local Registers/Wires

wire      [31:0]        status;

reg                     r_enable_pcie;
reg       [31:0]        r_clock_1_sec;
reg       [31:0]        r_clock_count;
reg       [31:0]        r_host_clock_count;
reg                     r_1sec_stb_100mhz;
wire                    w_1sec_stb_65mhz;

// Transaction (TRN) Interface
wire                    user_lnk_up;

  // Flow Control
wire      [2:0]         fc_sel;
wire      [7:0]         fc_nph;
wire      [11:0]        fc_npd;
wire      [7:0]         fc_ph;
wire      [11:0]        fc_pd;
wire      [7:0]         fc_cplh;
wire      [11:0]        fc_cpld;


// Host (CFG) Interface
wire      [31:0]        cfg_do;
wire                    cfg_rd_wr_done;
wire      [9:0]         cfg_dwaddr;
wire                    cfg_rd_en;

// Configuration: Error
wire                    cfg_err_ur;
wire                    cfg_err_cor;
wire                    cfg_err_ecrc;
wire                    cfg_err_cpl_timeout;
wire                    cfg_err_cpl_abort;
wire                    cfg_err_posted;
wire                    cfg_err_locked;
wire      [47:0]        cfg_err_tlp_cpl_header;
wire                    cfg_err_cpl_rdy;

// Conifguration: Interrupt
wire                    cfg_interrupt;
wire                    cfg_interrupt_rdy;
wire                    cfg_interrupt_assert;
wire      [7:0]         cfg_interrupt_do;
wire      [7:0]         cfg_interrupt_di;
wire      [2:0]         cfg_interrupt_mmenable;
wire                    cfg_interrupt_msienable;

// Configuration: Power Management
wire                    cfg_turnoff_ok;
wire                    cfg_to_turnoff;
wire                    cfg_pm_wake;

// Configuration: System/Status
wire      [2:0]         cfg_pcie_link_state;
reg                     r_cfg_trn_pending;
wire      [7:0]         cfg_bus_number;
wire      [4:0]         cfg_device_number;
wire      [2:0]         cfg_function_number;

wire      [15:0]        cfg_status;
wire      [15:0]        cfg_command;
wire      [15:0]        cfg_dstatus;
wire      [15:0]        cfg_dcommand;
wire      [15:0]        cfg_lstatus;
wire      [15:0]        cfg_lcommand;

// System Interface
wire                              pcie_reset;
wire                              pcie_clk;
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
wire  [CONTROL_FIFO_DEPTH -1: 0]  w_lcl_mem_addr;
reg   [31:0]                      r_lcl_mem_din;
wire  [31:0]                      w_lcl_mem_dout;
wire                              w_lcl_mem_valid;

wire                              w_lcl_mem_en;


wire                              w_cmd_in_rd_stb;
wire                              w_cmd_in_rd_ready;
wire                              w_cmd_in_rd_activate;
wire  [23:0]                      w_cmd_in_rd_size;
wire  [31:0]                      w_cmd_in_rd_data;

wire  [1:0]                       w_cmd_out_wr_ready;
wire  [1:0]                       w_cmd_out_wr_activate;
wire  [23:0]                      w_cmd_out_wr_size;
wire                              w_cmd_out_wr_stb;
wire  [31:0]                      w_cmd_out_wr_data;

wire                              w_data_in_rd_stb;
wire                              w_data_in_rd_ready;
wire                              w_data_in_rd_activate;
wire  [23:0]                      w_data_in_rd_size;
wire  [31:0]                      w_data_in_rd_data;

wire  [1:0]                       w_data_out_wr_ready;
wire  [1:0]                       w_data_out_wr_activate;
wire  [23:0]                      w_data_out_wr_size;
wire                              w_data_out_wr_stb;
wire  [31:0]                      w_data_out_wr_data;

reg   [1:0]                       r_rx_equalizer_ctrl;
reg   [3:0]                       r_tx_diff_ctrl;
wire  [4:0]                       cfg_ltssm_state;


//Submodules
artemis_pcie_interface #(
  .CONTROL_FIFO_DEPTH             (CONTROL_FIFO_DEPTH     ),
  .DATA_FIFO_DEPTH                (DATA_FIFO_DEPTH        ),
  .SERIAL_NUMBER                  (64'h000000000000C594   )
)api (
  .clk                            (clk                    ),
  .rst                            (rst || !r_enable_pcie  || !i_pcie_reset_n ),

  .gtp_clk_p                      (i_clk_100mhz_gtp_p     ),
  .gtp_clk_n                      (i_clk_100mhz_gtp_n     ),
  .pci_exp_txp                    (o_pcie_phy_tx_p        ),
  .pci_exp_txn                    (o_pcie_phy_tx_n        ),
  .pci_exp_rxp                    (i_pcie_phy_rx_p        ),
  .pci_exp_rxn                    (i_pcie_phy_rx_n        ),

  // Transaction (TRN) Interface
  .user_lnk_up                    (user_lnk_up            ),
  .pcie_clk                       (pcie_clk               ),

  // Flow Control
  .fc_sel                         (fc_sel                 ),
  .fc_nph                         (fc_nph                 ),
  .fc_npd                         (fc_npd                 ),
  .fc_ph                          (fc_ph                  ),
  .fc_pd                          (fc_pd                  ),
  .fc_cplh                        (fc_cplh                ),
  .fc_cpld                        (fc_cpld                ),

  // Host (CFG) Interface
  .cfg_do                         (cfg_do                 ),
  .cfg_rd_wr_done                 (cfg_rd_wr_done         ),
  .cfg_dwaddr                     (cfg_dwaddr             ),
  .cfg_rd_en                      (cfg_rd_en              ),

  // Configuration: Error
  .cfg_err_ur                     (cfg_err_ur             ),
  .cfg_err_cor                    (cfg_err_cor            ),
  .cfg_err_ecrc                   (cfg_err_ecrc           ),
  .cfg_err_cpl_timeout            (cfg_err_cpl_timeout    ),
  .cfg_err_cpl_abort              (cfg_err_cpl_abort      ),
  .cfg_err_posted                 (cfg_err_posted         ),
  .cfg_err_locked                 (cfg_err_locked         ),
  .cfg_err_tlp_cpl_header         (cfg_err_tlp_cpl_header ),
  .cfg_err_cpl_rdy                (cfg_err_cpl_rdy        ),

  // Conifguration: Interrupt
  .cfg_interrupt                  (cfg_interrupt          ),
  .cfg_interrupt_rdy              (cfg_interrupt_rdy      ),
  .cfg_interrupt_assert           (cfg_interrupt_assert   ),
  .cfg_interrupt_do               (cfg_interrupt_do       ),
  .cfg_interrupt_di               (cfg_interrupt_di       ),
  .cfg_interrupt_mmenable         (cfg_interrupt_mmenable ),
  .cfg_interrupt_msienable        (cfg_interrupt_msienable),

  // Configuration: Power Management
  .cfg_turnoff_ok                 (cfg_turnoff_ok         ),
  .cfg_to_turnoff                 (cfg_to_turnoff         ),
  .cfg_pm_wake                    (cfg_pm_wake            ),

  // Configuration: System/Status
  .cfg_pcie_link_state            (cfg_pcie_link_state    ),
  .cfg_trn_pending_stb            (r_cfg_trn_pending      ),
  .cfg_bus_number                 (cfg_bus_number         ),
  .cfg_device_number              (cfg_device_number      ),
  .cfg_function_number            (cfg_function_number    ),

  .cfg_status                     (cfg_status             ),
  .cfg_command                    (cfg_command            ),
  .cfg_dstatus                    (cfg_dstatus            ),
  .cfg_dcommand                   (cfg_dcommand           ),
  .cfg_lstatus                    (cfg_lstatus            ),
  .cfg_lcommand                   (cfg_lcommand           ),

  // System Interface
  .pcie_reset                     (pcie_reset             ),
  .received_hot_reset             (received_hot_reset     ),
  .gtp_pll_lock_detect            (gtp_pll_lock_detect    ),
  .gtp_reset_done                 (gtp_reset_done         ),
  .pll_lock_detect                (pll_lock_detect        ),
  .rx_elec_idle                   (rx_elec_idle           ),

  .i_cmd_in_rd_stb                (w_cmd_in_rd_stb        ),
  .o_cmd_in_rd_ready              (w_cmd_in_rd_ready      ),
  .i_cmd_in_rd_activate           (w_cmd_in_rd_activate   ),
  .o_cmd_in_rd_count              (w_cmd_in_rd_size       ),
  .o_cmd_in_rd_data               (w_cmd_in_rd_data       ),

  .o_cmd_out_wr_ready             (w_cmd_out_wr_ready     ),
  .i_cmd_out_wr_activate          (w_cmd_out_wr_activate  ),
  .o_cmd_out_wr_size              (w_cmd_out_wr_size      ),
  .i_cmd_out_wr_stb               (w_cmd_out_wr_stb       ),
  .i_cmd_out_wr_data              (w_cmd_out_wr_data      ),

  .i_data_in_rd_stb               (w_data_in_rd_stb       ),
  .o_data_in_rd_ready             (w_data_in_rd_ready     ),
  .i_data_in_rd_activate          (w_data_in_rd_activate  ),
  .o_data_in_rd_count             (w_data_in_rd_size     ),
  .o_data_in_rd_data              (w_data_in_rd_data      ),

  .o_data_out_wr_ready            (w_data_out_wr_ready    ),
  .i_data_out_wr_activate         (w_data_out_wr_activate ),
  .o_data_out_wr_size             (w_data_out_wr_size     ),
  .i_data_out_wr_stb              (w_data_out_wr_stb      ),
  .i_data_out_wr_data             (w_data_out_wr_data     ),

  .rx_equalizer_ctrl              (r_rx_equalizer_ctrl    ),
  .tx_diff_ctrl                   (r_tx_diff_ctrl         ),
  .cfg_ltssm_state                (cfg_ltssm_state        )


);

adapter_dpb_ppfifo #(
  .MEM_DEPTH                          (CONTROL_FIFO_DEPTH     ),
  .DATA_WIDTH                         (32                     )
)dpb_bridge (
  .clk                                (clk                    ),
  .rst                                (rst                    ),
  .i_ppfifo_2_mem_en                  (r_ppfifo_2_mem_en      ),
  .i_mem_2_ppfifo_stb                 (r_mem_2_ppfifo_stb     ),
  .i_cancel_write_stb                 (r_cancel_write_stb     ),
  .o_num_reads                        (w_num_reads            ),
  .o_idle                             (w_idle                 ),


  .i_bram_we                          (r_lcl_mem_we           ),
  .i_bram_addr                        (w_lcl_mem_addr         ),
  .i_bram_din                         (r_lcl_mem_din          ),
  .o_bram_dout                        (w_lcl_mem_dout         ),
  .o_bram_valid                       (w_lcl_mem_valid        ),


  .ppfifo_clk                         (clk                    ),

  .i_write_ready                      (w_cmd_out_wr_ready     ),
  .o_write_activate                   (w_cmd_out_wr_activate  ),
  .i_write_size                       (w_cmd_out_wr_size      ),
  .o_write_stb                        (w_cmd_out_wr_stb       ),
  .o_write_data                       (w_cmd_out_wr_data      ),

  .i_read_ready                       (w_cmd_in_rd_ready      ),
  .o_read_activate                    (w_cmd_in_rd_activate   ),
  .i_read_size                        (w_cmd_in_rd_size       ),
  .i_read_data                        (w_cmd_in_rd_data       ),
  .o_read_stb                         (w_cmd_in_rd_stb        )
);

cross_clock_strobe clk_stb(
  .rst                                (rst                    ),
  .in_clk                             (clk                    ),
  .in_stb                             (r_1sec_stb_100mhz      ),

  .out_clk                            (pcie_clk               ),
  .out_stb                            (w_1sec_stb_65mhz       )
);


//Asynchronous Logic
assign  fc_sel                 = 3'h0;

assign  cfg_dwaddr             = 10'h0;
assign  cfg_rd_en              = 1'b0;

assign  cfg_err_ur             = 0;
assign  cfg_err_cor            = 0;
assign  cfg_err_ecrc           = 0;
assign  cfg_err_cpl_timeout    = 0;
assign  cfg_err_cpl_abort      = 0;
assign  cfg_err_posted         = 0;
assign  cfg_err_locked         = 0;
assign  cfg_err_tlp_cpl_header = 0;

assign  cfg_interrupt          = 0;
assign  cfg_interrupt_assert   = 0;
assign  cfg_interrupt_di       = 0;

assign  cfg_turnoff_ok         = 0;
assign  cfg_pm_wake            = 0;


assign  w_data_in_rd_activate   = 0;
assign  w_data_in_rd_stb        = 0;

assign  w_data_out_wr_activate  = 0;
assign  w_data_out_wr_stb       = 0;
assign  w_data_out_wr_data      = 0;

assign  o_pcie_wake_n           = 0;


assign  w_lcl_mem_en            = ((i_wbs_adr >= `LOCAL_BUFFER_OFFSET) &&
                                   (i_wbs_adr < (`LOCAL_BUFFER_OFFSET + CONTROL_BUFFER_SIZE)));

assign  w_lcl_mem_addr          = w_lcl_mem_en ? (i_wbs_adr - `LOCAL_BUFFER_OFFSET) : 0;
//Synchronous Logic

always @ (posedge pcie_clk) begin
  if (rst) begin
    r_clock_1_sec   <=  0;
    r_clock_count   <=  0;
  end
  else begin
    r_clock_count   <=  r_clock_count + 1;
    if (w_1sec_stb_65mhz) begin
      r_clock_1_sec   <=  r_clock_count;
      r_clock_count   <=  0;
    end
  end
end


always @ (posedge clk) begin

  //Deassert Strobes
  r_mem_2_ppfifo_stb            <=  0;
  r_cancel_write_stb            <=  0;
  r_cfg_trn_pending             <=  0;
  r_lcl_mem_we                  <=  0;
  r_1sec_stb_100mhz             <=  0;

  if (rst) begin
    o_wbs_dat                   <=  32'h0;
    o_wbs_ack                   <=  0;
    o_wbs_int                   <=  0;
    r_ppfifo_2_mem_en           <=  0;
    r_enable_pcie               <=  1;

    r_lcl_mem_din               <=  0;
    r_host_clock_count          <=  0;

    r_rx_equalizer_ctrl         <=  2'b11;
    r_tx_diff_ctrl              <=  4'b1001;
  end
  else begin
    //when the master acks our ack, then put our ack down
    if (o_wbs_ack && ~i_wbs_stb)begin
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
              r_enable_pcie       <=  i_wbs_dat[`CTRL_BIT_ENABLE];
              r_mem_2_ppfifo_stb  <=  i_wbs_dat[`CTRL_BIT_SEND_CONTROL_BLOCK];
              r_cancel_write_stb  <=  i_wbs_dat[`CTRL_BIT_CANCEL_SEND_BLOCK];
              r_ppfifo_2_mem_en   <=  i_wbs_dat[`CTRL_BIT_ENABLE_LOCAL_READ];

            end
            TX_DIFF_CTRL: begin
              r_tx_diff_ctrl      <=  i_wbs_dat[3:0];
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
            end
            NUM_BLOCK_READ: begin
              o_wbs_dat <= w_num_reads;
            end
            LOCAL_BUFFER_SIZE: begin
              o_wbs_dat <= CONTROL_BUFFER_SIZE;
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
            RX_EQUALIZER_CTRL: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[1:0]  <=  r_rx_equalizer_ctrl;
            end
            LTSSM_STATE: begin
              o_wbs_dat       <=  0;
              o_wbs_dat[4:0]  <=  cfg_ltssm_state;
            end
            default: begin
              if (w_lcl_mem_en) begin
                o_wbs_dat                             <=  w_lcl_mem_dout;
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
