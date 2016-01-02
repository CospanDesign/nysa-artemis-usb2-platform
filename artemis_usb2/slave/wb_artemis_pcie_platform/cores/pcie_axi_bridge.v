module pcie_axi_bridge (
  // PCI Express Fabric Interface
  output            pci_exp_txp,
  output            pci_exp_txn,
  input             pci_exp_rxp,
  input             pci_exp_rxn,

  // Transaction (TRN) Interface
  output            user_lnk_up,

  // Tx
  output            s_axis_tx_tready,
  input  [31:0]     s_axis_tx_tdata,
  input  [3:0]      s_axis_tx_tkeep,
  input  [3:0]      s_axis_tx_tuser,
  input             s_axis_tx_tlast,
  input             s_axis_tx_tvalid,

  output     [5:0]  tx_buf_av,
  output            tx_err_drop,
  input             tx_cfg_gnt,
  output            tx_cfg_req,

  // Rx
  output  [31:0]    m_axis_rx_tdata,
  output  [3:0]     m_axis_rx_tkeep,
  output            m_axis_rx_tlast,
  output            m_axis_rx_tvalid,
  input             m_axis_rx_tready,
  output    [21:0]  m_axis_rx_tuser,
  input             rx_np_ok,

  // Flow Control
  input       [2:0] fc_sel,
  output      [7:0] fc_nph,
  output     [11:0] fc_npd,
  output      [7:0] fc_ph,
  output     [11:0] fc_pd,
  output      [7:0] fc_cplh,
  output     [11:0] fc_cpld,

  // Host (CFG) Interface
  output     [31:0] cfg_do,
  output            cfg_rd_wr_done,
  input       [9:0] cfg_dwaddr,
  input             cfg_rd_en,

  // Configuration: Error
  input             cfg_err_ur,
  input             cfg_err_cor,
  input             cfg_err_ecrc,
  input             cfg_err_cpl_timeout,
  input             cfg_err_cpl_abort,
  input             cfg_err_posted,
  input             cfg_err_locked,
  input      [47:0] cfg_err_tlp_cpl_header,
  output            cfg_err_cpl_rdy,

  // Conifguration: Interrupt
  input             cfg_interrupt,
  output            cfg_interrupt_rdy,
  input             cfg_interrupt_assert,
  output      [7:0] cfg_interrupt_do,
  input       [7:0] cfg_interrupt_di,
  output      [2:0] cfg_interrupt_mmenable,
  output            cfg_interrupt_msienable,

  // Configuration: Power Management
  input             cfg_turnoff_ok,
  output            cfg_to_turnoff,
  input             cfg_pm_wake,

  // Configuration: System/Status
  output      [2:0] cfg_pcie_link_state,
  input             cfg_trn_pending,
  input      [63:0] cfg_dsn,
  output      [7:0] cfg_bus_number,
  output      [4:0] cfg_device_number,
  output      [2:0] cfg_function_number,

  output     [15:0] cfg_status,
  output     [15:0] cfg_command,
  output     [15:0] cfg_dstatus,
  output     [15:0] cfg_dcommand,
  output     [15:0] cfg_lstatus,
  output     [15:0] cfg_lcommand,

  // System Interface
  input             sys_clk_p,
  input             sys_clk_n,
  input             sys_reset,
  output            user_clk_out,
  output            user_reset_out,
  output            received_hot_reset

);
endmodule
