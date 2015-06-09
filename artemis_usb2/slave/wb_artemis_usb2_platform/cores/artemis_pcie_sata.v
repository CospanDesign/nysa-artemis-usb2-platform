module artemis_pcie_sata (
  //------------------------------- PLL Ports --------------------------------
  input          i_sata_reset,
  input          i_pcie_reset,

  output         o_sata_pll_detect_k,
  output         o_pcie_pll_detect_k,

  output         o_sata_reset_done,
  output         o_pcie_reset_done,

  output         o_sata_75mhz_clk,
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
  output  [2:0]  o_sata_rx_status,
  output  [2:0]  o_pcie_rx_status,
  //------------ Receive Ports - RX Pipe Control for PCI Express -------------
  output         o_pcie_phy_status,
  output         o_pcie_phy_rx_valid,
  //------------------ Receive Ports - RX Polarity Control -------------------
  input          i_pcie_rx_polarity,
  //----------------- Transmit Ports - 8b10b Encoder Control -----------------
  input   [3:0]  i_pcie_disparity_mode,
  input   [3:0]  i_sata_tx_char_is_k,
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
endmodule
