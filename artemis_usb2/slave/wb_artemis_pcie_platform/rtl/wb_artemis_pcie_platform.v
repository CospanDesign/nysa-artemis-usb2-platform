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

`define CTRL_BIT_SOURCE_EN      0
`define CTRL_BIT_CANCEL_WRITE   1
`define CTRL_BIT_SINK_EN        2


`define STS_BIT_LINKUP          0
`define STS_BIT_READ_IDLE       1
`define STS_PER_FIFO_SEL        2
`define STS_MEM_FIFO_SEL        3
`define STS_DMA_FIFO_SEL        4
`define STS_WRITE_EN            5
`define STS_READ_EN             6


`define LOCAL_BUFFER_OFFSET         24'h000100

module wb_artemis_pcie_platform #(
  parameter           DATA_INGRESS_FIFO_DEPTH = 10,
  parameter           DATA_EGRESS_FIFO_DEPTH  = 6,
  parameter           CONTROL_FIFO_DEPTH = 7
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

  output      [31:0]  o_debug_data,
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
localparam  CONTROL             = 32'h00;
localparam  STATUS              = 32'h01;
localparam  CFG_READ_EXEC       = 32'h02;
localparam  CFG_SM_STATE        = 32'h03;
localparam  CTR_SM_STATE        = 32'h04;
localparam  INGRESS_COUNT       = 32'h05;
localparam  INGRESS_STATE       = 32'h06;
localparam  INGRESS_RI_COUNT    = 32'h07;
localparam  INGRESS_CI_COUNT    = 32'h08;
localparam  INGRESS_ADDR        = 32'h09;
localparam  INGRESS_CMPLT_COUNT = 32'h0A;
localparam  IH_STATE            = 32'h0B;
localparam  OH_STATE            = 32'h0C;
localparam  BRAM_NUM_READS      = 32'h0D;
localparam  LOCAL_BUFFER_SIZE   = 32'h0E;
localparam  DBG_ID_VALUE        = 32'h0F;
localparam  DBG_COMMAND_VALUE   = 32'h10;
localparam  DBG_COUNT_VALUE     = 32'h11;
localparam  DBG_ADDRESS_VALUE   = 32'h12;

localparam    CONTROL_BUFFER_SIZE = 2 ** CONTROL_FIFO_DEPTH;

//Local Registers/Wires
reg               r_mem_2_ppfifo_stb;
reg               r_snk_en;

wire  [1:0]       w_mem_gen_rdy;
wire  [23:0]      w_mem_gen_size;
wire  [1:0]       w_mem_gen_act;
wire              w_mem_gen_stb;
wire  [31:0]      w_mem_gen_data;

wire              w_mem_sink_rdy;
wire  [23:0]      w_mem_sink_size;
wire              w_mem_sink_act;
wire              w_mem_sink_stb;
wire  [31:0]      w_mem_sink_data;

wire              w_odma_flush;
wire              w_idma_flush;

wire  [1:0]       w_dma_gen_rdy;
wire  [23:0]      w_dma_gen_size;
wire  [1:0]       w_dma_gen_act;
wire              w_dma_gen_stb;
wire  [31:0]      w_dma_gen_data;

wire              w_dma_sink_rdy;
wire  [23:0]      w_dma_sink_size;
wire              w_dma_sink_act;
wire              w_dma_sink_stb;
wire  [31:0]      w_dma_sink_data;


wire              out_en;
wire  [31:0]      out_status;
wire  [31:0]      out_address;
wire  [31:0]      out_data;
wire  [27:0]      out_data_count;
wire              master_ready;

wire              w_in_ready;
wire  [31:0]      w_in_command;
wire  [31:0]      w_in_address;
wire  [31:0]      w_in_data;
wire  [27:0]      w_in_data_count;
wire              w_out_ready;
wire              w_ih_reset;

wire              w_per_stb;
wire              w_per_cyc;
reg               r_per_ack;
reg   [31:0]      r_per_data;

//Submodules
  //Memory Interface
  //DDR3 Control Signals
wire              o_ddr3_cmd_clk;
wire              o_ddr3_cmd_en;
wire  [2:0]       o_ddr3_cmd_instr;
wire  [5:0]       o_ddr3_cmd_bl;
wire  [29:0]      o_ddr3_cmd_byte_addr;
wire              i_ddr3_cmd_empty;
wire              i_ddr3_cmd_full;

wire              o_ddr3_wr_clk;
wire              o_ddr3_wr_en;
wire  [3:0]       o_ddr3_wr_mask;
wire  [31:0]      o_ddr3_wr_data;
wire              i_ddr3_wr_full;
wire              i_ddr3_wr_empty;
wire  [6:0]       i_ddr3_wr_count;
wire              i_ddr3_wr_underrun;
wire              i_ddr3_wr_error;

wire              o_ddr3_rd_clk;
wire              o_ddr3_rd_en;
wire  [31:0]      i_ddr3_rd_data;
wire              i_ddr3_rd_full;
wire              i_ddr3_rd_empty;
wire  [6:0]       i_ddr3_rd_count;
wire              i_ddr3_rd_overflow;
wire              i_ddr3_rd_error;
wire  [31:0]      w_usr_interrupt_value;
wire              w_interrupt;

wire      [7:0]   o_cfg_read_exec;
wire      [3:0]   o_cfg_sm_state;
wire      [3:0]   o_sm_state;
wire      [7:0]   o_ingress_count;
wire      [3:0]   o_ingress_state;
wire      [7:0]   o_ingress_ri_count;
wire      [7:0]   o_ingress_ci_count;
wire      [31:0]  o_ingress_cmplt_count;
wire      [31:0]  o_ingress_addr;

assign  w_interrupt   = 0;

wire      [3:0]      w_ih_state;
wire      [3:0]      w_oh_state;


reg                   r_cancel_write_stb;
wire      [31:0]      w_num_reads;
wire                  w_read_idle;


wire                  w_lcl_mem_en;

reg                   r_bram_we;
wire      [6:0]       w_bram_addr;
reg       [31:0]      r_bram_din;
wire      [31:0]      w_bram_dout;
wire                  w_bram_valid;

wire      [31:0]      w_id_value;
wire      [31:0]      w_command_value;
wire      [31:0]      w_count_value;
wire      [31:0]      w_address_value;

wire                  w_per_fifo_sel;
wire                  w_mem_fifo_sel;
wire                  w_dma_fifo_sel;

wire                  w_write_flag;
wire                  w_read_flag;



artemis_pcie_host_interface host_interface (

  .clk                  (clk                  ),
  .rst                  (rst                  ),

  .i_interrupt          (w_interrupt          ),
  .o_user_lnk_up        (w_user_lnk_up        ),
  .o_pcie_rst_out       (w_pcie_rst_out       ),

  .i_usr_interrupt_value(w_usr_interrupt_value),

  //Master Interface
  .i_master_ready       (master_ready         ),

  .o_ih_reset           (w_ih_reset           ),
  .o_ih_ready           (w_in_ready           ),

  .o_in_command         (w_in_command         ),
  .o_in_address         (w_in_address         ),
  .o_in_data            (w_in_data            ),
  .o_in_data_count      (w_in_data_count      ),

  .o_oh_ready           (w_out_ready          ),
  .i_oh_en              (out_en               ),

  .i_out_status         (out_status           ),
  .i_out_address        (out_address          ),
  .i_out_data           (out_data             ),
  .i_out_data_count     (out_data_count       ),

  .o_ih_state           (w_ih_state           ),
  .o_oh_state           (w_oh_state           ),


  //Memory Interface
  //DDR3 Control Signals
  .o_ddr3_cmd_clk       (o_ddr3_cmd_clk       ),
  .o_ddr3_cmd_en        (o_ddr3_cmd_en        ),
  .o_ddr3_cmd_instr     (o_ddr3_cmd_instr     ),
  .o_ddr3_cmd_bl        (o_ddr3_cmd_bl        ),
  .o_ddr3_cmd_byte_addr (o_ddr3_cmd_byte_addr ),
  .i_ddr3_cmd_empty     (i_ddr3_cmd_empty     ),
  .i_ddr3_cmd_full      (i_ddr3_cmd_full      ),

  .o_ddr3_wr_clk        (o_ddr3_wr_clk        ),
  .o_ddr3_wr_en         (o_ddr3_wr_en         ),
  .o_ddr3_wr_mask       (o_ddr3_wr_mask       ),
  .o_ddr3_wr_data       (o_ddr3_wr_data       ),
  .i_ddr3_wr_full       (i_ddr3_wr_full       ),
  .i_ddr3_wr_empty      (i_ddr3_wr_empty      ),
  .i_ddr3_wr_count      (i_ddr3_wr_count      ),
  .i_ddr3_wr_underrun   (i_ddr3_wr_underrun   ),
  .i_ddr3_wr_error      (i_ddr3_wr_error      ),

  .o_ddr3_rd_clk        (o_ddr3_rd_clk        ),
  .o_ddr3_rd_en         (o_ddr3_rd_en         ),
  .i_ddr3_rd_data       (i_ddr3_rd_data       ),
  .i_ddr3_rd_full       (i_ddr3_rd_full       ),
  .i_ddr3_rd_empty      (i_ddr3_rd_empty      ),
  .i_ddr3_rd_count      (i_ddr3_rd_count      ),
  .i_ddr3_rd_overflow   (i_ddr3_rd_overflow   ),
  .i_ddr3_rd_error      (i_ddr3_rd_error      ),

  .i_idma_flush         (w_idma_flush         ),
  .i_idma_activate      (w_dma_sink_act       ),
  .o_idma_ready         (w_dma_sink_rdy       ),
  .i_idma_stb           (w_dma_sink_stb       ),
  .o_idma_size          (w_dma_sink_size      ),
  .o_idma_data          (w_dma_sink_data      ),

  .i_odma_flush         (w_odma_flush         ),
  .o_odma_ready         (w_dma_gen_rdy        ),
  .i_odma_activate      (w_dma_gen_act        ),
  .i_odma_stb           (w_dma_gen_stb        ),
  .o_odma_size          (w_dma_gen_size       ),
  .i_odma_data          (w_dma_gen_data       ),

  .o_cfg_read_exec      (o_cfg_read_exec      ),
  .o_cfg_sm_state       (o_cfg_sm_state       ),
  .o_sm_state           (o_sm_state           ),
  .o_ingress_count      (o_ingress_count      ),
  .o_ingress_state      (o_ingress_state      ),
  .o_ingress_ri_count   (o_ingress_ri_count   ),
  .o_ingress_ci_count   (o_ingress_ci_count   ),
  .o_ingress_cmplt_count(o_ingress_cmplt_count),
  .o_ingress_addr       (o_ingress_addr       ),

  .o_id_value           (w_id_value           ),
  .o_command_value      (w_command_value      ),
  .o_count_value        (w_count_value        ),
  .o_address_value      (w_address_value      ),

  .o_per_fifo_sel       (w_per_fifo_sel       ),
  .o_mem_fifo_sel       (w_mem_fifo_sel       ),
  .o_dma_fifo_sel       (w_dma_fifo_sel       ),

  .o_write_flag         (w_write_flag         ),
  .o_read_flag          (w_read_flag          ),

  .o_debug_data         (o_debug_data         ),

  .i_pcie_phy_clk_p     (i_clk_100mhz_gtp_p   ),
  .i_pcie_phy_clk_n     (i_clk_100mhz_gtp_n   ),

  .o_pcie_phy_tx_p      (o_pcie_phy_tx_p      ),
  .o_pcie_phy_tx_n      (o_pcie_phy_tx_n      ),

  .i_pcie_phy_rx_p      (i_pcie_phy_rx_p      ),
  .i_pcie_phy_rx_n      (i_pcie_phy_rx_n      ),

  .i_pcie_reset         (!i_pcie_reset_n      ),
  .o_pcie_wake_n        (o_pcie_wake_n        )

);

wishbone_master wm (
  .clk                  (clk                  ),
  .rst                  (rst                  ),

  .i_ih_rst             (w_ih_reset           ),
  .i_ready              (w_in_ready           ),
  .i_command            (w_in_command         ),
  .i_address            (w_in_address         ),
  .i_data               (w_in_data            ),
  .i_data_count         (w_in_data_count      ),
  .i_out_ready          (w_out_ready          ),
  .o_en                 (out_en               ),
  .o_status             (out_status           ),
  .o_address            (out_address          ),
  .o_data               (out_data             ),
  .o_data_count         (out_data_count       ),
  .o_master_ready       (master_ready         ),

//  .o_per_we             (w_wbp_we               ),
//  .o_per_adr            (w_wbp_adr              ),
//  .o_per_dat            (w_wbp_dat_i            ),
  .i_per_dat            (r_per_data             ),
  .o_per_stb            (w_per_stb              ),
  .o_per_cyc            (w_per_cyc              ),
//  .o_per_msk            (w_wbp_msk              ),
//  .o_per_sel            (w_wbp_sel              ),
  .i_per_ack            (r_per_ack              ),
  .i_per_int            (1'b0                   ),  //Try this out later on

  //memory interconnect signals
//  .o_mem_we             (w_mem_we_o             ),
//  .o_mem_adr            (w_mem_adr_o            ),
//  .o_mem_dat            (w_mem_dat_o            ),
//  .i_mem_dat            (w_mem_dat_i            ),
//  .o_mem_stb            (w_mem_stb_o            ),
//  .o_mem_cyc            (w_mem_cyc_o            ),
//  .o_mem_sel            (w_mem_sel_o            ),
  .i_mem_ack            (1'b0                   ),  //Nothing should be on the memory bus
  .i_mem_int            (1'b0                   )

);

//DMA Sink and Source
adapter_dpb_ppfifo #(
  .MEM_DEPTH                  (CONTROL_FIFO_DEPTH     ),
  .DATA_WIDTH                 (32                     )
) dma_bram (
  .clk                        (clk                    ),
  .rst                        (rst                    ),
  .i_ppfifo_2_mem_en          (r_snk_en               ),
  .i_mem_2_ppfifo_stb         (r_mem_2_ppfifo_stb     ),
  .i_cancel_write_stb         (r_cancel_write_stb     ),
  .o_num_reads                (w_num_reads            ),
  .o_idle                     (w_read_idle            ),

  //User Memory Interface
  .i_bram_we                  (r_bram_we              ),
  .i_bram_addr                (w_bram_addr            ),
  .i_bram_din                 (r_bram_din             ),
  .o_bram_dout                (w_bram_dout            ),
  .o_bram_valid               (w_bram_valid           ),

  //Ping Pong FIFO Interface
  .ppfifo_clk                 (clk                    ),

  .i_write_ready              (w_dma_gen_rdy          ),
  .o_write_activate           (w_dma_gen_act          ),
  .i_write_size               (w_dma_gen_size         ),
  .o_write_stb                (w_dma_gen_stb          ),
  .o_write_data               (w_dma_gen_data         ),

  .i_read_ready               (w_dma_sink_rdy         ),
  .o_read_activate            (w_dma_sink_act         ),
  .i_read_size                (w_dma_sink_size        ),
  .o_read_stb                 (w_dma_sink_stb         ),
  .i_read_data                (w_dma_sink_data        )
);


assign i_ddr3_cmd_empty   = 1;
assign i_ddr3_cmd_full    = 0;

assign i_ddr3_wr_full     = 0;
assign i_ddr3_wr_empty    = 1;
assign i_ddr3_wr_count    = 0;
assign i_ddr3_wr_underrun = 0;
assign i_ddr3_wr_error    = 0;

assign i_ddr3_rd_data     = 32'h01234567;
assign i_ddr3_rd_full     = 1;
assign i_ddr3_rd_empty    = 0;
assign i_ddr3_rd_count    = 63;
assign i_ddr3_rd_overflow = 0;
assign i_ddr3_rd_error    = 0;

//Asynchronous Logic
assign  w_odma_flush      = 0;
assign  w_idma_flush      = 0;

assign  w_usr_interrupt_value = 32'h0;


assign  w_lcl_mem_en            = ((i_wbs_adr >= `LOCAL_BUFFER_OFFSET) &&
                                   (i_wbs_adr < (`LOCAL_BUFFER_OFFSET + CONTROL_BUFFER_SIZE)));

assign  w_bram_addr             = w_lcl_mem_en ? (i_wbs_adr - `LOCAL_BUFFER_OFFSET) : 0;

//Synchronous Logic

always @ (posedge clk) begin
  if (rst) begin
    r_per_data    <=  0;
    r_per_ack     <=  0;
  end
  else begin
    if (!w_per_stb && r_per_ack) begin
      r_per_ack   <=  0;
    end
    if (w_per_cyc && w_per_stb && !r_per_ack) begin
      r_per_ack   <=  1;
      r_per_data  <=  r_per_data + 1;
    end
  end
end

always @ (posedge clk) begin
  r_mem_2_ppfifo_stb      <= 0;
  r_cancel_write_stb      <= 0;
  r_bram_we               <=  0;
  if (rst) begin
    o_wbs_dat             <= 32'h0;
    o_wbs_ack             <= 0;
    o_wbs_int             <= 0;
    r_bram_din            <= 0;

    r_snk_en              <= 1;
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
              r_mem_2_ppfifo_stb                  <=  i_wbs_dat[`CTRL_BIT_SOURCE_EN];
              r_cancel_write_stb                  <=  i_wbs_dat[`CTRL_BIT_CANCEL_WRITE];
              r_snk_en                            <=  i_wbs_dat[`CTRL_BIT_SINK_EN];
            end
            default: begin
              if (w_lcl_mem_en) begin
                r_bram_we                          <=  1;
                r_bram_din                         <=  i_wbs_dat;
              end

            end
          endcase
          o_wbs_ack                                 <= 1;
        end
        else begin
          //read request
          case (i_wbs_adr)
            CONTROL: begin
              o_wbs_dat <= 0;
              o_wbs_dat[`CTRL_BIT_SOURCE_EN]      <= r_mem_2_ppfifo_stb;
              o_wbs_dat[`CTRL_BIT_CANCEL_WRITE]   <= r_cancel_write_stb;
              o_wbs_dat[`CTRL_BIT_SINK_EN]        <= r_snk_en;

            end
            STATUS: begin
              o_wbs_dat <= 0;
              o_wbs_dat[`STS_BIT_LINKUP]          <=  w_user_lnk_up;
              o_wbs_dat[`STS_BIT_READ_IDLE]       <=  w_read_idle;

              o_wbs_dat[`STS_PER_FIFO_SEL]        <=  w_per_fifo_sel;
              o_wbs_dat[`STS_MEM_FIFO_SEL]        <=  w_mem_fifo_sel;
              o_wbs_dat[`STS_DMA_FIFO_SEL]        <=  w_dma_fifo_sel;
              o_wbs_dat[`STS_WRITE_EN]            <=  w_write_flag;
              o_wbs_dat[`STS_READ_EN]             <=  w_read_flag;

            end
            CFG_READ_EXEC: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_cfg_read_exec;
            end
            CFG_SM_STATE: begin
              o_wbs_dat <= 0;
              o_wbs_dat[3:0]  <=   o_cfg_sm_state;
            end
            CTR_SM_STATE: begin
              o_wbs_dat <= 0;
              o_wbs_dat[3:0]  <=   o_sm_state;
            end
            INGRESS_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_ingress_count;
            end
            INGRESS_STATE: begin
              o_wbs_dat <= 0;
              o_wbs_dat[3:0]  <=   o_ingress_state;
            end
            INGRESS_RI_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_ingress_ri_count;
            end
            INGRESS_CI_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[7:0]  <=   o_ingress_ci_count;
            end
            INGRESS_ADDR: begin
              o_wbs_dat <= 0;
              o_wbs_dat[31:0]  <=  o_ingress_addr;
            end
            INGRESS_CMPLT_COUNT: begin
              o_wbs_dat <= 0;
              o_wbs_dat[31:0]  <=  o_ingress_cmplt_count;
            end
            IH_STATE: begin
              o_wbs_dat         <= 0;
              o_wbs_dat[3:0]    <=  w_ih_state;
            end
            OH_STATE: begin
              o_wbs_dat         <= 0;
              o_wbs_dat[3:0]    <=  w_oh_state;
            end
            BRAM_NUM_READS: begin
              o_wbs_dat         <=  w_num_reads;
            end
            LOCAL_BUFFER_SIZE: begin
              o_wbs_dat         <= CONTROL_BUFFER_SIZE;
            end
            DBG_ID_VALUE: begin
              o_wbs_dat         <=  w_id_value;
            end
            DBG_COMMAND_VALUE: begin
              o_wbs_dat         <=  w_command_value;
            end
            DBG_COUNT_VALUE: begin
              o_wbs_dat         <=  w_count_value;
            end
            DBG_ADDRESS_VALUE: begin
              o_wbs_dat         <=  w_address_value;
            end
            //add as many ADDR_X you need here
            default: begin
              if (w_lcl_mem_en) begin
                o_wbs_dat         <=  w_bram_dout;
              end
            end
          endcase
          if (w_bram_valid) begin
            o_wbs_ack             <=  1;
          end
        end
      end
    end
  end
end

endmodule
