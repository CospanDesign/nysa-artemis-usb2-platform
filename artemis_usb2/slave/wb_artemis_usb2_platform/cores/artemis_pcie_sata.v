module artemis_pcie_sata (
  //------------------------------- PLL Ports --------------------------------
  input           i_sata_reset,
  input           i_pcie_reset,

  output          o_sata_pll_detect_k,
  output          o_pcie_pll_detect_k,

  output          o_sata_reset_done,
  output          o_pcie_reset_done,

  output          o_sata_75mhz_clk,
  output          o_pcie_62p5mhz_clk,

  output          o_sata_dcm_locked,
  output          o_pcie_dcm_locked,

  //--------------------- Receive Ports - 8b10b Decoder ----------------------
  output          o_sata_char_is_comma,
  output          o_sata_rx_char_is_k,
  output          o_pcie_rx_char_is_k,
  output          o_sata_disperity_error,
  output          o_pcie_disperity_error,
  output          o_sata_rx_not_in_table,
  output          o_pcie_rx_not_in_table,
  //-------------------- Receive Ports - Clock Correction --------------------
  output          o_sata_clk_correct_count,
  output          o_pcie_clk_correct_count,
  //----------------- Receive Ports - RX Data Path interface -----------------
  output  [31:0]  o_sata_data_out,
  output  [31:0]  o_pcie_data_out,
  input           i_pcie_rx_reset,
  //----- Receive Ports - RX Driver,OOB signalling,Coupling and Eq.,CDR ------
  output          o_sata_rx_elec_idle,
  output          o_pcie_rx_elec_idle,
  input   [2:0]   i_rx_pre_amp,

  input           i_sata_phy_rx_p,
  input           i_sata_phy_rx_n,

  input           i_pcie_phy_rx_p,
  input           i_pcie_phy_rx_n,
  //--------- Receive Ports - RX Elastic Buffer and Phase Alignment ----------
  //------------ Receive Ports - RX Pipe Control for PCI Express -------------
  output  [1:0]   o_pcie_phy_status,
  output  [1:0]   o_pcie_phy_rx_valid,
  //------------------ Receive Ports - RX Polarity Control -------------------
  input           i_pcie_rx_polarity,
  //----------------- Transmit Ports - 8b10b Encoder Control -----------------
  input   [1:0]   i_pcie_disparity_mode,
  input           i_sata_tx_char_is_k,
  input           i_pcie_tx_char_is_k,
  //---------------- Transmit Ports - TX Data Path interface -----------------
  input   [31:0]  i_sata_tx_data,
  input   [31:0]  i_pcie_tx_data,
  //------------- Transmit Ports - TX Driver and OOB signalling --------------
  input   [3:0]   i_tx_diff_swing,
  output          o_sata_phy_tx_p,
  output          o_sata_phy_tx_n,

  output          o_pcie_phy_tx_p,
  output          o_pcie_phy_tx_n,
  //--------------- Transmit Ports - TX Ports for PCI Express ----------------
  input           i_pcie_tx_detect_rx,
  input           i_sata_tx_elec_idle,
  input           i_pcie_tx_elec_idle,
  //------------------- Transmit Ports - TX Ports for SATA -------------------
  input           i_sata_tx_comm_start,
  input           i_sata_tx_comm_type,

  input           i_gtp0_clk_p,
  input           i_gtp0_clk_n,

  input           i_gtp1_clk_p,
  input           i_gtp1_clk_n
);
endmodule
