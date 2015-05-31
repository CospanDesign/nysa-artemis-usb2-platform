//wb_artemis_usb2_platform.v
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
  SDB_DEVICE_ID:0x00000000

  Set the version of the Core XX.XXX.XXX Example: 01.000.000
  SDB_CORE_VERSION:00.000.001

  Set the Device Name: 19 UNICODE characters
  SDB_NAME:artemis_usb2

  Set the class of the device (16 bits) Set as 0
  SDB_ABI_CLASS:0

  Set the ABI Major Version: (8-bits)
  SDB_ABI_VERSION_MAJOR:0x022

  Set the ABI Minor Version (8-bits)
  SDB_ABI_VERSION_MINOR:0x03

  Set the Module URL (63 Unicode Characters)
  SDB_MODULE_URL:http://www.artemis.cospandesign.com

  Set the date of module YYYY/MM/DD
  SDB_DATE:2015/05/23

  Device is executable (True/False)
  SDB_EXECUTABLE:True

  Device is readable (True/False)
  SDB_READABLE:True

  Device is writeable (True/False)
  SDB_WRITEABLE:True

  Device Size: Number of Registers
  SDB_SIZE:2
*/
`include "artemis_usb2_platform_defines.v"
`unconnected_drive pull0


module wb_artemis_usb2_platform #(
//  parameter           RX_PREAMP = 2'h2,
//  parameter           TX_DIFF   = 4'h4

)(
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

  output  reg         o_wbs_int,
  output              o_platform_ready,

  //--SATA Interface--
  output              o_sata_75mhz_clk,
  output              o_sata_error,

  //  GTP: Control/Data Interface
  output      [3:0]   o_sata_rx_char_is_k,
  output      [31:0]  o_sata_rx_data,
  input       [3:0]   i_sata_tx_char_is_k,
  input       [31:0]  i_sata_tx_data,

  //  GTP: OOB Signals
  output              o_sata_tx_oob_complete,
  input               i_sata_tx_elec_idle,
  input               i_sata_tx_comm_init,
  input               i_sata_tx_comm_wake,
  output              o_sata_rx_elec_idle,
  output              o_sata_rx_comm_wake_detect,
  output              o_sata_rx_comm_init_detect,


  //OPTIONAL
  output      [2:0]   o_sata_clk_correct_count,
  output      [3:0]   o_sata_char_is_comma,

  //--PCIE Interface--
  output              o_pcie_62p5mhz_clk,
  output              o_pcie_error,

  //  GTP: Control/Data Interface
  output      [3:0]   o_pcie_rx_char_is_k,
  input       [3:0]   i_pcie_tx_char_is_k,
  output      [31:0]  o_pcie_rx_data,
  input       [31:0]  i_pcie_tx_data,
  output              o_pcie_phy_rx_valid,

  // GTP: OOB Signals
  input               i_pcie_tx_detect_rx,
  input               i_pcie_tx_elec_idle,
  input       [3:0]   i_pcie_disparity_mode,
  output              o_pcie_phy_status,
  output              o_pcie_rx_elec_idle,

  //OPTIONAL
  output      [2:0]   o_pcie_clk_correct_count,

  //Physical Signals
  input               i_gtp0_clk_p,
  input               i_gtp0_clk_n,

  input               i_gtp1_clk_p,
  input               i_gtp1_clk_n,

  input               i_sata_phy_rx_p,
  input               i_sata_phy_rx_n,

  input               i_pcie_phy_rx_p,
  input               i_pcie_phy_rx_n,

  output              o_sata_phy_tx_p,
  output              o_sata_phy_tx_n,

  output              o_pcie_phy_tx_p,
  output              o_pcie_phy_tx_n
);

//Local Parameters
localparam     GTP_CONTROL  = 32'h00000000;
localparam     GTP_STATUS   = 32'h00000001;

//Local Registers/Wires
reg   [31:0]        gtp_control = 32'h00;
wire  [31:0]        gtp_status;

wire                pcie_rx_polarity;
wire                usr_cntrl_reset;
wire                sata_reset;
wire                pcie_reset;

wire  [1:0]         rx_pre_amp;
wire  [3:0]         tx_diff_swing;

wire                sata_pll_detect_k;
wire                pcie_pll_detect_k;

wire                sata_reset_done;
wire                pcie_reset_done;

wire                sata_dcm_locked;
wire                pcie_dcm_locked;

reg                 sata_tx_comm_start = 0;
reg                 sata_tx_comm_type = 0;

wire  [2:0]         sata_rx_status;
wire  [2:0]         pcie_rx_status;

wire                sata_loss_of_sync;
wire                pcie_loss_of_sync;
wire  [3:0]         sata_disparity_error;
wire  [3:0]         pcie_disparity_error;
wire  [3:0]         sata_rx_not_in_table;
wire  [3:0]         pcie_rx_not_in_table;

//Submodules
artemis_pcie_sata aps(
  .i_sata_reset             (sata_reset               ),
  .i_pcie_reset             (pcie_reset               ),

  .o_sata_pll_detect_k      (sata_pll_detect_k        ),
  .o_pcie_pll_detect_k      (pcie_pll_detect_k        ),

  .o_sata_reset_done        (sata_reset_done          ),
  .o_pcie_reset_done        (pcie_reset_done          ),

  .o_sata_75mhz_clk         (o_sata_75mhz_clk         ),
  .o_pcie_62p5mhz_clk       (o_pcie_62p5mhz_clk       ),

  .o_sata_dcm_locked        (sata_dcm_locked          ),
  .o_pcie_dcm_locked        (pcie_dcm_locked          ),

  .o_sata_loss_of_sync      (sata_loss_of_sync        ),
  .o_pcie_loss_of_sync      (pcie_loss_of_sync        ),

  .o_sata_char_is_comma     (o_sata_char_is_comma     ),
  .o_sata_rx_char_is_k      (o_sata_rx_char_is_k      ),
  .o_pcie_rx_char_is_k      (o_pcie_rx_char_is_k      ),
  .o_sata_disparity_error   (sata_disparity_error     ),
  .o_pcie_disparity_error   (pcie_disparity_error     ),
  .o_sata_rx_not_in_table   (sata_rx_not_in_table     ),
  .o_pcie_rx_not_in_table   (pcie_rx_not_in_table     ),
  .o_sata_clk_correct_count (o_sata_clk_correct_count ),
  .o_pcie_clk_correct_count (o_pcie_clk_correct_count ),
  .o_sata_rx_data           (o_sata_rx_data           ),
  .o_pcie_rx_data           (o_pcie_rx_data           ),
  .o_sata_rx_elec_idle      (o_sata_rx_elec_idle      ),
  .o_pcie_rx_elec_idle      (o_pcie_rx_elec_idle      ),
  .i_sata_rx_pre_amp        (rx_pre_amp               ),

  .o_sata_rx_status         (sata_rx_status           ),
  .o_pcie_rx_status         (pcie_rx_status           ),

  .i_sata_phy_rx_p          (i_sata_phy_rx_p          ),
  .i_sata_phy_rx_n          (i_sata_phy_rx_n          ),

  .i_pcie_phy_rx_p          (i_pcie_phy_rx_p          ),
  .i_pcie_phy_rx_n          (i_pcie_phy_rx_n          ),
  .o_pcie_phy_status        (o_pcie_phy_status        ),
  .o_pcie_phy_rx_valid      (o_pcie_phy_rx_valid      ),
  .i_pcie_rx_polarity       (pcie_rx_polarity         ),
  .i_pcie_disparity_mode    (i_pcie_disparity_mode    ),
  .i_sata_tx_char_is_k      (i_sata_tx_char_is_k      ),
  .i_pcie_tx_char_is_k      (i_pcie_tx_char_is_k      ),
  .i_sata_tx_data           (i_sata_tx_data           ),
  .i_pcie_tx_data           (i_pcie_tx_data           ),
  .i_tx_diff_swing          (tx_diff_swing            ),
  .o_sata_phy_tx_p          (o_sata_phy_tx_p          ),
  .o_sata_phy_tx_n          (o_sata_phy_tx_n          ),

  .o_pcie_phy_tx_p          (o_pcie_phy_tx_p          ),
  .o_pcie_phy_tx_n          (o_pcie_phy_tx_n          ),
  .i_pcie_tx_detect_rx      (i_pcie_tx_detect_rx      ),
  .i_sata_tx_elec_idle      (i_sata_tx_elec_idle      ),
  .i_pcie_tx_elec_idle      (i_pcie_tx_elec_idle      ),
  .i_sata_tx_comm_start     (sata_tx_comm_start       ),
  .i_sata_tx_comm_type      (sata_tx_comm_type        ),

  .i_gtp0_clk_p             (i_gtp0_clk_p             ),
  .i_gtp0_clk_n             (i_gtp0_clk_n             ),

  .i_gtp1_clk_p             (i_gtp1_clk_p             ),
  .i_gtp1_clk_n             (i_gtp1_clk_n             )
);

//Asynchronous Logic
assign    rx_pre_amp                        = gtp_control[`GTP_RX_PRE_AMP_HIGH      :`GTP_RX_PRE_AMP_LOW    ];
assign    tx_diff_swing                     = gtp_control[`GTP_TX_DIFF_SWING_HIGH   :`GTP_TX_DIFF_SWING_LOW ];

//assign    pcie_rx_polarity                  = gtp_control[`PCIE_RX_POLARITY];
assign    pcie_rx_polarity                  = 1'b0;
assign    sata_reset                        = rst || gtp_control[`SATA_RESET];

assign    pcie_reset                        = rst || gtp_control[`PCIE_RESET];

assign    o_sata_tx_oob_complete            = sata_rx_status[0];
assign    o_sata_rx_comm_wake_detect        = sata_rx_status[1];
assign    o_sata_rx_comm_init_detect        = sata_rx_status[2];

assign    o_sata_error                      = (sata_disparity_error > 0) || (sata_rx_not_in_table > 0) || sata_loss_of_sync;
assign    o_pcie_error                      = (pcie_disparity_error > 0) || (pcie_rx_not_in_table > 0) || pcie_loss_of_sync;

assign    o_platform_ready                  = (!sata_reset && sata_pll_detect_k && sata_dcm_locked && sata_reset_done);

//Translate SATA friendly signals to GTP Friendly signals
always @ (posedge o_sata_75mhz_clk or posedge sata_reset) begin
  if (sata_reset) begin
    sata_tx_comm_start  <=  0;
    sata_tx_comm_type   <=  0;
  end
  else begin
    if (!sata_reset_done) begin
      sata_tx_comm_start  <=  0;
      sata_tx_comm_type   <=  0;
    end
    else begin
      sata_tx_comm_start  <=  0;
      sata_tx_comm_type   <=  i_sata_tx_comm_wake;
      if (sata_tx_comm_type || i_sata_tx_comm_init) begin
        sata_tx_comm_start  <=  1;
      end
    end
  end
end


assign    gtp_status[`SATA_PLL_DETECT_K   ]  = sata_pll_detect_k;
assign    gtp_status[`PCIE_PLL_DETECT_K   ]  = pcie_pll_detect_k;
assign    gtp_status[`SATA_RESET_DONE     ]  = sata_reset_done;
assign    gtp_status[`PCIE_RESET_DONE     ]  = pcie_reset_done;
assign    gtp_status[`SATA_DCM_PLL_LOCKED ]  = sata_dcm_locked;
assign    gtp_status[`PCIE_DCM_PLL_LOCKED ]  = pcie_dcm_locked;
assign    gtp_status[`SATA_RX_IDLE        ]  = o_sata_rx_elec_idle;
assign    gtp_status[`PCIE_RX_IDLE        ]  = o_pcie_rx_elec_idle;
assign    gtp_status[`SATA_TX_IDLE        ]  = i_sata_tx_elec_idle;
assign    gtp_status[`PCIE_TX_IDLE        ]  = i_pcie_tx_elec_idle;
assign    gtp_status[`SATA_LOSS_OF_SYNC   ]  = sata_loss_of_sync;
assign    gtp_status[`PCIE_LOSS_OF_SYNC   ]  = pcie_loss_of_sync;

//Synchronous Logic
always @ (posedge clk) begin
  if (rst) begin
    o_wbs_dat                   <=  32'h0;
    o_wbs_ack                   <=  0;
    gtp_control                 <=  0;
    o_wbs_int                   <=  0;
    gtp_control[`SATA_RESET]    <=  0;
    gtp_control[`PCIE_RESET]    <=  1;
    gtp_control[`GTP_RX_PRE_AMP_HIGH      :`GTP_RX_PRE_AMP_LOW    ] <= RX_PREAMP;
    gtp_control[`GTP_TX_DIFF_SWING_HIGH   :`GTP_TX_DIFF_SWING_LOW ] <= TX_DIFF;

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
            GTP_CONTROL: begin
              gtp_control       <=  i_wbs_dat;
            end
            default: begin
            end
          endcase
        end
        else begin
          //read request
          case (i_wbs_adr)
            GTP_CONTROL: begin
              o_wbs_dat         <=  gtp_control;
            end
            GTP_STATUS: begin
              o_wbs_dat         <= gtp_status;
            end
            default: begin
            end
          endcase
        end
      o_wbs_ack <= 1;
    end
    end
  end
end

endmodule
