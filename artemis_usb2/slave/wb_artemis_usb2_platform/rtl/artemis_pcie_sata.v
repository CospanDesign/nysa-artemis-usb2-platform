module artemis_pcie_sata (
  //------------------------------- PLL Ports --------------------------------
  input          i_sata_reset,
  input          i_pcie_reset,

  output         o_sata_pll_detect_k,
  output         o_pcie_pll_detect_k,

  output         o_sata_reset_done,
  output         o_pcie_reset_done,

  output         o_sata_75mhz_clk,
  output         o_sata_300mhz_clk,
  output         o_pcie_62p5mhz_clk,

  output         o_sata_dcm_locked,
  output         o_pcie_dcm_locked,

  //------------- Receive Ports - RX Loss-of-sync State Machine --------------
  output  [1:0]  o_sata_loss_of_sync,
  output  [1:0]  o_pcie_loss_of_sync,
  //--------------------- Receive Ports - 8b10b Decoder ----------------------
  output  [3:0]  o_sata_rx_char_is_comma,
  output  [3:0]  o_sata_rx_char_is_k,
  output  [3:0]  o_pcie_rx_char_is_k,
  output  [3:0]  o_sata_disparity_error,
  output  [3:0]  o_pcie_disparity_error,
  output  [3:0]  o_sata_rx_not_in_table,
  output  [3:0]  o_pcie_rx_not_in_table,
  //-------------------- Receive Ports - Clock Correction --------------------
  output  [2:0]  o_sata_clk_correct_count,
  output  [2:0]  o_pcie_clk_correct_count,
  //----------------- Receive Ports - RX Data Path interface -----------------
  output  [31:0] o_sata_rx_data,
  output  [31:0] o_pcie_rx_data,
  //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
  output         o_sata_rx_elec_idle,
  output         o_pcie_rx_elec_idle,
  input   [1:0]  i_sata_rx_pre_amp,

  input          i_sata_phy_rx_p,
  input          i_sata_phy_rx_n,

  input          i_pcie_phy_rx_p,
  input          i_pcie_phy_rx_n,

  //--------- Receive Ports - RX Elastic Buffer and Phase Alignment ----------
  output         o_sata_rx_byte_is_aligned,
  output         o_pcie_rx_byte_is_aligned,
  output  [2:0]  o_sata_rx_status,
  output  [2:0]  o_pcie_rx_status,
  //------------ Receive Ports - RX Pipe Control for PCI Express -------------
  output         o_pcie_phy_status,
  output         o_pcie_phy_rx_valid,
  //------------------ Receive Ports - RX Polarity Control -------------------
  input          i_pcie_rx_polarity,
  //----------------- Transmit Ports - 8b10b Encoder Control -----------------
  input   [3:0]  i_pcie_disparity_mode,
  input          i_sata_tx_char_is_k,
  input   [3:0]  i_pcie_tx_char_is_k,
  //---------------- Transmit Ports - TX Data Path interface -----------------
  input   [31:0] i_sata_tx_data,
  input   [31:0] i_pcie_tx_data,
  //------------- Transmit Ports - TX Driver and OOB signalling --------------
  input   [3:0]  i_tx_diff_swing,
  output         o_sata_phy_tx_p,
  output         o_sata_phy_tx_n,

  output         o_pcie_phy_tx_p,
  output         o_pcie_phy_tx_n,
  //--------------- Transmit Ports - TX Ports for PCI Express ----------------
  input          i_pcie_tx_detect_rx,
  input          i_sata_tx_elec_idle,
  input          i_pcie_tx_elec_idle,
  //------------------- Transmit Ports - TX Ports for SATA -------------------
  input          i_sata_tx_comm_start,
  input          i_sata_tx_comm_type,

  input          i_gtp0_clk_p,
  input          i_gtp0_clk_n,

  input          i_gtp1_clk_p,
  input          i_gtp1_clk_n
);

//Registers/Wires

wire    sata_300mhz_clk;
wire    sata_75mhz_clk;

//Feeds into the Pre DCM Buffer
wire    [1:0] sata_gtp_clkout;

//From Pre DCM Buffer to DCM
wire    sata_dcm_clkin;
wire    sata_dcm_reset;

wire    [1:0] pcie_gtp_clkout;
//wire    pcie_gtp_clkout;
wire    pcie_dcm_clkin;
wire    pcie_dcm_reset;

wire    pcie_250mhz_clk;
wire    pcie_rx_reset;

wire    tile0_gtp0_refclk_i;
wire    tile0_gtp1_refclk_i;

//wire    sata_txout;
//wire    pcie_txout;


aps#(
    .WRAPPER_SIM_GTPRESET_SPEEDUP   (0                       ),      // Set this to 1 for simulation
    .WRAPPER_SIMULATION             (0                       ),     // Set this to 1 for simulation
    .WRAPPER_CLK25_DIVIDER_0        (6                       ),
    .WRAPPER_CLK25_DIVIDER_1        (4                       ),

    //SATA 3GHz: N1 = 5, N2 = 2, D = 1, M = 1
    .WRAPPER_PLL_DIVSEL_FB_0        (2                       ),     // N2 = 2
    .WRAPPER_PLL_DIVSEL_REF_0       (1                       ),     // M = 1

    //PCIE 2.5GHz N1 = 5, N2 = 5, D = 1, M = 2
    .WRAPPER_PLL_DIVSEL_FB_1        (5                       ),     // N2 = 5
    .WRAPPER_PLL_DIVSEL_REF_1       (2                       )      // M = 2

)
artemis_pcie_sata_i(

    //_____________________________________________________________________
    //_____________________________________________________________________
    //TILE0  (X0_Y0)

    //---------------------- Loopback and Powerdown Ports ----------------------
    .TILE0_RXPOWERDOWN1_IN          (2'b0                    ),
    .TILE0_TXPOWERDOWN1_IN          (2'b0                    ),
    //------------------------------- PLL Ports --------------------------------
    .TILE0_CLK00_IN                 (tile0_gtp0_refclk_i     ),
    .TILE0_CLK01_IN                 (tile0_gtp1_refclk_i     ),
    .TILE0_GTPRESET0_IN             (i_sata_reset            ),
    .TILE0_GTPRESET1_IN             (i_pcie_reset            ),
    .TILE0_PLLLKDET0_OUT            (o_sata_pll_detect_k     ),
    .TILE0_PLLLKDET1_OUT            (o_pcie_pll_detect_k     ),
    .TILE0_RESETDONE0_OUT           (o_sata_reset_done       ),
    .TILE0_RESETDONE1_OUT           (o_pcie_reset_done       ),
    //--------------------- Receive Ports - 8b10b Decoder ----------------------
    .TILE0_RXCHARISCOMMA0_OUT       (o_sata_rx_char_is_comma ),
    .TILE0_RXCHARISK0_OUT           (o_sata_rx_char_is_k     ),
    .TILE0_RXCHARISK1_OUT           (o_pcie_rx_char_is_k     ),
    .TILE0_RXDISPERR0_OUT           (o_sata_disparity_error  ),
    .TILE0_RXDISPERR1_OUT           (o_pcie_disparity_error  ),
    .TILE0_RXNOTINTABLE0_OUT        (o_sata_rx_not_in_table  ),
    .TILE0_RXNOTINTABLE1_OUT        (o_pcie_rx_not_in_table  ),
    //-------------------- Receive Ports - Clock Correction --------------------
    .TILE0_RXCLKCORCNT0_OUT         (o_sata_clk_correct_count),
    .TILE0_RXCLKCORCNT1_OUT         (o_pcie_clk_correct_count),
    //------------- Receive Ports - Comma Detection and Alignment --------------
    .TILE0_RXENMCOMMAALIGN0_IN      (1'b1                    ),
    .TILE0_RXENMCOMMAALIGN1_IN      (1'b1                    ),
//XXX: should PCIE PLL Be aligned to both commas?
    .TILE0_RXENPCOMMAALIGN0_IN      (1'b1                    ),
    .TILE0_RXENPCOMMAALIGN1_IN      (1'b1                    ),
    //----------------- Receive Ports - RX Data Path interface -----------------
    .TILE0_RXDATA0_OUT              (o_sata_rx_data          ),
    .TILE0_RXDATA1_OUT              (o_pcie_rx_data          ),
    .TILE0_RXRECCLK0_OUT            (                        ),
    .TILE0_RXRESET1_IN              (pcie_rx_reset           ),
    .TILE0_RXUSRCLK0_IN             (sata_300mhz_clk         ),
    .TILE0_RXUSRCLK1_IN             (pcie_250mhz_clk         ),
    .TILE0_RXUSRCLK20_IN            (sata_75mhz_clk          ),
    .TILE0_RXUSRCLK21_IN            (o_pcie_62p5mhz_clk      ),
    //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
//XXX: tied 0 for both PCIE and SATA
    .TILE0_GATERXELECIDLE0_IN       (1'b0                    ),
    .TILE0_GATERXELECIDLE1_IN       (1'b0                    ),
//XXX: tied 0 for both PCIE and SATA
    .TILE0_IGNORESIGDET0_IN         (1'b0                    ),
    .TILE0_IGNORESIGDET1_IN         (1'b0                    ),
    .TILE0_RXELECIDLE0_OUT          (o_sata_rx_elec_idle     ),
    .TILE0_RXELECIDLE1_OUT          (o_pcie_rx_elec_idle     ),
    .TILE0_RXEQMIX0_IN              (i_sata_rx_pre_amp       ),
    .TILE0_RXP0_IN                  (i_sata_phy_rx_p         ),
    .TILE0_RXN0_IN                  (i_sata_phy_rx_n         ),
    .TILE0_RXP1_IN                  (i_pcie_phy_rx_p         ),
    .TILE0_RXN1_IN                  (i_pcie_phy_rx_n         ),
    //--------- Receive Ports - RX Elastic Buffer and Phase Alignment ----------
    .TILE0_RXBYTEALIGNED0_OUT       (o_sata_rx_byte_is_aligned ),
    .TILE0_RXBYTEALIGNED1_OUT       (o_pcie_rx_byte_is_aligned ),
    .TILE0_RXSTATUS0_OUT            (o_sata_rx_status        ),
    .TILE0_RXSTATUS1_OUT            (o_pcie_rx_status        ),
    //------------- Receive Ports - RX Loss-of-sync State Machine --------------
    .TILE0_RXLOSSOFSYNC0_OUT        (o_sata_loss_of_sync     ),
    .TILE0_RXLOSSOFSYNC1_OUT        (o_pcie_loss_of_sync     ),
    //------------ Receive Ports - RX Pipe Control for PCI Express -------------
    .TILE0_PHYSTATUS1_OUT           (o_pcie_phy_status       ),
    .TILE0_RXVALID1_OUT             (o_pcie_phy_rx_valid     ),
    //------------------ Receive Ports - RX Polarity Control -------------------
    .TILE0_RXPOLARITY1_IN           (i_pcie_rx_polarity      ),
    //-------------------------- TX/RX Datapath Ports --------------------------
    .TILE0_GTPCLKOUT0_OUT           (sata_gtp_clkout         ),
    .TILE0_GTPCLKOUT1_OUT           (pcie_gtp_clkout         ),
    //----------------- Transmit Ports - 8b10b Encoder Control -----------------
    .TILE0_TXCHARDISPMODE1_IN       (i_pcie_disparity_mode   ),
    .TILE0_TXCHARISK0_IN            ({1'b0, 1'b0, 1'b0, i_sata_tx_char_is_k}),
    .TILE0_TXCHARISK1_IN            (i_pcie_tx_char_is_k     ),
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .TILE0_TXDATA0_IN               (i_sata_tx_data          ),
    .TILE0_TXDATA1_IN               (i_pcie_tx_data          ),
    .TILE0_TXOUTCLK0_OUT            (                        ),
    .TILE0_TXOUTCLK1_OUT            (                        ),
    .TILE0_TXUSRCLK0_IN             (sata_300mhz_clk         ),
    .TILE0_TXUSRCLK1_IN             (pcie_250mhz_clk         ),
    .TILE0_TXUSRCLK20_IN            (sata_75mhz_clk          ),
    .TILE0_TXUSRCLK21_IN            (o_pcie_62p5mhz_clk      ),
    //------------- Transmit Ports - TX Driver and OOB signalling --------------
    .TILE0_TXDIFFCTRL0_IN           (i_tx_diff_swing         ),
    .TILE0_TXP0_OUT                 (o_sata_phy_tx_p         ),
    .TILE0_TXN0_OUT                 (o_sata_phy_tx_n         ),
    .TILE0_TXP1_OUT                 (o_pcie_phy_tx_p         ),
    .TILE0_TXN1_OUT                 (o_pcie_phy_tx_n         ),
    //--------------- Transmit Ports - TX Ports for PCI Express ----------------
    .TILE0_TXDETECTRX1_IN           (i_pcie_tx_detect_rx     ),
    .TILE0_TXELECIDLE0_IN           (i_sata_tx_elec_idle     ),
    .TILE0_TXELECIDLE1_IN           (i_pcie_tx_elec_idle     ),
    //------------------- Transmit Ports - TX Ports for SATA -------------------
    .TILE0_TXCOMSTART0_IN           (i_sata_tx_comm_start    ),
    .TILE0_TXCOMTYPE0_IN            (i_sata_tx_comm_type     )
);

//---------------------Dedicated GTP Reference Clock Inputs ---------------
// Each dedicated refclk you are using in your design will need its own IBUFDS instance

//SATA Clock Path
IBUFDS tile0_gtp0_refclk_ibufds_i(
    .O                              (tile0_gtp0_refclk_i     ),
    .I                              (i_gtp0_clk_p            ),  // Connect to package pin A10
    .IB                             (i_gtp0_clk_n            )   // Connect to package pin B10
);

//PHY Signals -> IBUFDS -> GTP PLL -> BUFIO2 -> PLL (Frequency Synthesis) -> All Sata Clocks
//150 MHz diff -> IBUFDS -> GTP PLL -> BUFIO2 (150MHz) -> PLL_ADV -> (USERCLK1: 300MHz, USRCLK2: 75MHz)
BUFIO2 #(
    .DIVIDE                         (1),
    .DIVIDE_BYPASS                  ("TRUE")
) i_sata_pll_buf (
    .I                              (sata_gtp_clkout[0]),
    .DIVCLK                         (sata_dcm_clkin),
    .IOCLK                          (),
    .SERDESSTROBE                   ()
);

assign  sata_dcm_reset                = !o_sata_pll_detect_k;
//wire    sata_pll_feedback;
wire    sata_75mhz_bufg_in;
wire    sata_300mhz_bufg_in;

//wire    sata_pll_feedback_out;
wire    sata_pll_feedback;

/*
BUFG sata_fb_bufg(
    .I                              (sata_pll_feedback_out),
    .O                              (sata_txout)
);
*/

/*
BUFIO2FB sata_clkfb(
    .I                              (sata_pll_feedback_out),
    .O                              (sata_pll_feedback)
);
*/


PLL_BASE #(
  .CLKFBOUT_MULT                    (4                    ),
  .DIVCLK_DIVIDE                    (1                    ),
  .CLK_FEEDBACK                     ("CLKFBOUT"           ),
  .COMPENSATION                     ("SYSTEM_SYNCHRONOUS" ),
  .CLKIN_PERIOD                     (6.666                ),
  .CLKOUT0_DIVIDE                   (2                    ),
  .CLKOUT0_PHASE                    (0                    ),
  .CLKOUT1_DIVIDE                   (8                    ),
  .CLKOUT1_PHASE                    (0                    )
)
SATA_PLL(
  .CLKIN                            (sata_dcm_clkin       ),
  //.CLKINSEL                         (1'b1                 ),
  .CLKOUT0                          (sata_300mhz_bufg_in  ),
  .CLKOUT1                          (sata_75mhz_bufg_in   ),
  .CLKOUT2                          (                     ),
  .CLKOUT3                          (                     ),
  .CLKOUT4                          (                     ),
  .CLKOUT5                          (                     ),
  .CLKFBOUT                         (sata_pll_feedback    ),
  .CLKFBIN                          (sata_pll_feedback    ),
  .LOCKED                           (o_sata_dcm_locked    ),
  .RST                              (sata_dcm_reset       )
);

BUFG  SATA_75MHZ_BUFG (
  .I                                (sata_75mhz_bufg_in   ),
  .O                                (sata_75mhz_clk       )
);

BUFG SATA_300MHZ_BUFG (
  .I                                (sata_300mhz_bufg_in  ),
  .O                                (sata_300mhz_clk      )
);

assign  o_sata_75mhz_clk            = sata_75mhz_clk;
assign  o_sata_300mhz_clk           = sata_300mhz_clk;

//PCIE Clock Path
/* PHY Signals -> IBUFDS -> GTP PLL -> BUFIO2 -> PLL (Frequency Synthesis) -> All PCIE Clocks
 * 300 MHz diff -> IBUFDS -> GTP PLL -> BUFIO2 (300MHz) -> PLL_ADV -> (USERCLK1: 300MHz, USRCLK2: 62P5MHz)
 */

IBUFDS tile0_gtp1_refclk_ibufds_i(
    .O                              (tile0_gtp1_refclk_i),
    .I                              (i_gtp1_clk_p),  // Connect to package pin C11
    .IB                             (i_gtp1_clk_n)   // Connect to package pin D11
);

BUFIO2 #(
    .DIVIDE                         (1),
    .DIVIDE_BYPASS                  ("TRUE")
) i_pcie_pll_buf (
    .I                              (pcie_gtp_clkout[0]),
    //.I                              (pcie_gtp_clkout),
    .DIVCLK                         (pcie_dcm_clkin),
    .IOCLK                          (),
    .SERDESSTROBE                   ()
);

assign  pcie_dcm_reset              = !o_pcie_pll_detect_k;
//wire    pcie_pll_feedback;
wire    pcie_62p5mhz_bufg_in;
wire    pcie_250mhz_bufg_in;
wire    pcie_pll_feedback_out;

/*
BUFG pcie_clk_bufg(
    .I                              (pcie_pll_feedback_out),
    .O                              (pcie_txout)
);

BUFIO2FB pcie_clkfb(
    .I                              (pcie_txout),
    .O                              (pcie_pll_feedback)
);
*/


PLL_BASE #(
  .CLKFBOUT_MULT                    (10                   ),
  .DIVCLK_DIVIDE                    (1                    ),
  .CLK_FEEDBACK                     ("CLKFBOUT"           ),
  .COMPENSATION                     ("SYSTEM_SYNCHRONOUS" ),
  .CLKIN_PERIOD                     (10.000               ),
  .CLKOUT0_DIVIDE                   (4                    ),
  .CLKOUT0_PHASE                    (0                    ),
  .CLKOUT1_DIVIDE                   (16                   ),
  .CLKOUT1_PHASE                    (0                    )
)
PCIE_PLL(
  .CLKIN                            (pcie_dcm_clkin       ),
  //.CLKINSEL                         (1'b1                 ),
  .CLKOUT0                          (pcie_250mhz_bufg_in  ),
  .CLKOUT1                          (pcie_62p5mhz_bufg_in ),
  .CLKOUT2                          (                     ),
  .CLKOUT3                          (                     ),
  .CLKOUT4                          (                     ),
  .CLKOUT5                          (                     ),
  .CLKFBOUT                         (pcie_pll_feedback_out),
  .CLKFBIN                          (pcie_pll_feedback_out),
  .LOCKED                           (o_pcie_dcm_locked    ),
  .RST                              (pcie_dcm_reset       )
);

BUFG  PCIE_62P5MHZ_BUFG (
  .I                                (pcie_62p5mhz_bufg_in ),
  .O                                (o_pcie_62p5mhz_clk   )
);

BUFG PCIE_250MHZ_BUFG (
  .I                                (pcie_250mhz_bufg_in  ),
  .O                                (pcie_250mhz_clk      )
);

assign pcie_rx_reset  = !(o_pcie_dcm_locked && o_pcie_pll_detect_k);

endmodule
