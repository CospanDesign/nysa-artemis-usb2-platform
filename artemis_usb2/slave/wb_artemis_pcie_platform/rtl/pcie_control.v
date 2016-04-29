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
 * Author:
 * Description:
 *
 * Changes:
 */
`include "pcie_defines.v"
`include "nysa_pcie_defines.v"

module pcie_control(
  input                     clk,
  input                     rst,

  //Configuration Values
  input       [7:0]         i_pcie_bus_num,
  input       [4:0]         i_pcie_dev_num,
  input       [2:0]         i_pcie_fun_num,

  //Ingress Machine Interface
  input       [31:0]        i_write_a_addr,
  input       [31:0]        i_write_b_addr,
  input       [31:0]        i_read_a_addr,
  input       [31:0]        i_read_b_addr,
  input       [31:0]        i_status_addr,
  input       [31:0]        i_buffer_size,
  input       [31:0]        i_dev_addr,
  input       [31:0]        i_ping_value,
  input       [1:0]         i_update_buf,
  input                     i_update_buf_stb,

  input                     i_reg_write_stb,

  //Nysa Interface
  input       [31:0]        i_interrupt_value,
  input                     i_interrupt_stb,

  //In band reset
  input                     i_cmd_rst_stb,

  //Command Strobes
  input                     i_cmd_wr_stb,
  input                     i_cmd_rd_stb,

  input                     i_cmd_flg_fifo,
  input                     i_cmd_flg_sel_periph,
  input                     i_cmd_flg_sel_memory,
  input                     i_cmd_flg_sel_dma,

  input                     i_cmd_ping_stb,
  input                     i_cmd_rd_cfg_stb,
  input                     i_cmd_unknown,

  input       [31:0]        i_cmd_data_count,
  input       [31:0]        i_cmd_data_address,

  //User Control Interface
  output  reg               o_per_sel,
  output  reg               o_mem_sel,
  output  reg               o_dma_sel,
  output                    o_data_fifo_sel,

  output  reg [31:0]        o_data_size,
  output  reg [31:0]        o_data_address,
  output  reg               o_data_fifo_flg,
  output  reg               o_data_read_flg,
  output  reg               o_data_write_flg,

  //Flow Controller
  input                     i_pcie_fc_ready,

  //Peripheral/Memory/DMA Egress FIFO Interface
  input                     i_e_fifo_rdy,
  input       [23:0]        i_e_fifo_size,

  //Egress State Machine
  output                    o_egress_enable,
  input                     i_egress_finished,
  output      [7:0]         o_egress_tlp_command,
  output      [13:0]        o_egress_tlp_flags,
  output      [31:0]        o_egress_tlp_address,
  output      [15:0]        o_egress_tlp_requester_id,
  output      [7:0]         o_egress_tag,

  //Egress FIFO for control data
  output  reg               o_ctr_sel,
  output  reg [7:0]         o_interrupt_msi_value,
  output  reg               o_interrupt_stb,

  output                    o_egress_fifo_rdy,
  input                     i_egress_fifo_act,
  output      [23:0]        o_egress_fifo_size,
  input                     i_egress_fifo_stb,
  output      [31:0]        o_egress_fifo_data,

  output                    o_sys_rst,
  output  reg [7:0]         o_cfg_read_exec,
  output      [3:0]         o_cfg_sm_state,
  output      [3:0]         o_sm_state

);


//local parameters
localparam      IDLE                          = 4'h0;

localparam      EGRESS_DATA_FLOW              = 4'h1;
localparam      WAIT_FOR_HOST_EGRESS_BUFFER   = 4'h2;
localparam      WAIT_FOR_FPGA_EGRESS_FIFO     = 4'h3;
localparam      SEND_EGRESS_DATA              = 4'h4;
localparam      INGRESS_DATA_FLOW             = 4'h5;
localparam      WAIT_FOR_FPGA_INGRESS_FIFO    = 4'h6;
localparam      WAIT_FOR_HOST_INGRESS_BUFFER  = 4'h7;
localparam      WAIT_FOR_FLOW_CONTROL         = 4'h8;
localparam      SEND_INGRESS_DATA             = 4'h9;
localparam      SEND_EGRESS_STATUS_SLEEP      = 4'hA;
localparam      SEND_EGRESS_STATUS            = 4'hB;

localparam      SEND_CONFIG                   = 4'hC;
localparam      SEND_CONFIG_SLEEP             = 4'hD;
localparam      WAIT_FOR_CONFIG               = 4'hE;


localparam      PREPARE                       = 4'h1;
localparam      LOAD_FIFO                     = 4'h2;
localparam      CFG_SEND_CONFIG               = 4'h3;
localparam      SEND_INT                      = 4'h4;

//registes/wires

reg   [3:0]                 state;

wire  [1:0]                 w_fifo_rdy;
reg   [1:0]                 r_fifo_act;
wire  [23:0]                w_fifo_size;
reg                         r_fifo_stb;
reg   [31:0]                r_fifo_data;

reg   [4:0]                 r_fifo_count;

wire  [31:0]                register_map  [`CONFIG_REGISTER_COUNT:0];

wire  [31:0]                w_comm_status;

wire                        w_sts_ready;
reg                         r_sts_ping;
reg                         r_sts_read_cfg;
reg                         r_sts_unknown_cmd;
reg                         r_sts_interrupt;
wire                        w_sts_flg_fifo_stall;
wire                        w_sts_hst_buf_stall;
reg                         r_sts_cmd_err;
reg                         r_sts_reset;
reg                         r_sts_done;


reg   [31:0]                r_data_count;
reg   [31:0]                r_data_pos;
reg   [23:0]                r_block_count;
reg   [23:0]                r_fifo_size;

wire                        w_control_sm_idle;
wire                        w_config_sm_idle;

reg                         r_buf_sel;
reg                         r_buf_next_sel;
reg   [1:0]                 r_buf_rdy;
reg   [1:0]                 r_buf_done;

reg                         r_send_data_en;

reg   [7:0]                 r_tlp_command;          //XXX: When send to host MWR, when get from host MRD
reg   [13:0]                r_tlp_flags;
reg   [31:0]                r_tlp_address;          //XXX: Need to figure out this!
reg   [15:0]                r_tlp_requester_id;     //XXX: Need to figure out this!
reg   [7:0]                 r_tlp_tag;              //XXX: Need to figure out this!


//Configuration State Machine
reg   [3:0]                 cfg_state;
wire                        r_cfg_ready;
reg                         r_send_cfg_stb;
reg                         r_send_cfg_en;


//Convenience Signals
wire                        w_valid_bus_select;

wire  [31:0]                write_buf_map [0:1];
assign  write_buf_map[0]  = i_write_a_addr;
assign  write_buf_map[1]  = i_write_b_addr;


wire  [31:0]                read_buf_map [0:1];
assign  read_buf_map[0]   = i_read_a_addr;
assign  read_buf_map[1]   = i_read_b_addr;


//submodules
ppfifo #(
  .DATA_WIDTH       (32                 ),
  .ADDRESS_WIDTH    (4                  ) //16 32-bit values for the control
) egress_fifo(
  .reset            (rst || i_cmd_rst_stb),
  //Write Side
  .write_clock      (clk                ),
  .write_ready      (w_fifo_rdy         ),
  .write_activate   (r_fifo_act         ),
  .write_fifo_size  (w_fifo_size        ),
  .write_strobe     (r_fifo_stb         ),
  .write_data       (r_fifo_data        ),

  //Read Side
  .read_clock       (clk                ),
  .read_ready       (o_egress_fifo_rdy  ),
  .read_activate    (i_egress_fifo_act  ),
  .read_count       (o_egress_fifo_size ),
  .read_strobe      (i_egress_fifo_stb  ),
  .read_data        (o_egress_fifo_data )
);

//asynchronous logic
assign  register_map [`HDR_STATUS_BUF_ADDR      ] = i_status_addr;
assign  register_map [`HDR_BUFFER_READY         ] = {29'h00, r_buf_rdy};
assign  register_map [`HDR_WRITE_BUF_A_ADDR     ] = i_write_a_addr;
assign  register_map [`HDR_WRITE_BUF_B_ADDR     ] = i_write_b_addr;
assign  register_map [`HDR_READ_BUF_A_ADDR      ] = i_read_a_addr;
assign  register_map [`HDR_READ_BUF_B_ADDR      ] = i_read_b_addr;
assign  register_map [`HDR_BUFFER_SIZE          ] = i_buffer_size;
assign  register_map [`HDR_PING_VALUE           ] = i_ping_value;
assign  register_map [`HDR_DEV_ADDR             ] = i_dev_addr;
assign  register_map [`STS_DEV_STATUS           ] = w_comm_status;
assign  register_map [`STS_BUF_RDY              ] = {29'h00, r_buf_done[1] , r_buf_done[0] };
assign  register_map [`STS_BUF_POS              ] = r_data_pos;
assign  register_map [`STS_INTERRUPT            ] = i_interrupt_value;


//Status Register
assign  w_comm_status[`STATUS_UNUSED            ] = 0;
assign  w_comm_status[`STATUS_BIT_CMD_ERR       ] = r_sts_cmd_err;
assign  w_comm_status[`STATUS_BIT_RESET         ] = r_sts_reset;
assign  w_comm_status[`STATUS_BIT_DONE          ] = r_sts_done;
assign  w_comm_status[`STATUS_BIT_READY         ] = w_sts_ready;
assign  w_comm_status[`STATUS_BIT_WRITE         ] = o_data_write_flg;
assign  w_comm_status[`STATUS_BIT_READ          ] = o_data_read_flg;
assign  w_comm_status[`STATUS_BIT_FIFO          ] = o_data_fifo_flg;
assign  w_comm_status[`STATUS_BIT_PING          ] = r_sts_ping;
assign  w_comm_status[`STATUS_BIT_READ_CFG      ] = r_sts_read_cfg;
assign  w_comm_status[`STATUS_BIT_UNKNOWN_CMD   ] = r_sts_unknown_cmd;
assign  w_comm_status[`STATUS_BIT_PPFIFO_STALL  ] = w_sts_flg_fifo_stall;
assign  w_comm_status[`STATUS_BIT_HOST_BUF_STALL] = w_sts_hst_buf_stall;
assign  w_comm_status[`STATUS_BIT_PERIPH        ] = o_per_sel;
assign  w_comm_status[`STATUS_BIT_MEM           ] = o_mem_sel;
assign  w_comm_status[`STATUS_BIT_DMA           ] = o_dma_sel;
assign  w_comm_status[`STATUS_BIT_INTERRUPT     ] = r_sts_interrupt;




assign  o_sys_rst                           = i_cmd_rst_stb;

assign  o_data_fifo_sel                     = (!r_send_cfg_en) ? (o_per_sel || o_mem_sel || o_dma_sel): 1'b0;
assign  o_egress_enable                     = r_send_cfg_en || r_send_data_en;
assign  o_egress_tlp_command                = (r_send_cfg_en) ? `PCIE_MWR_32B:
                                                                r_tlp_command;

assign  o_egress_tlp_flags                  = (r_send_cfg_en) ? (`FLAG_NORMAL):
                                                                r_tlp_flags;
assign  o_egress_tlp_address                = (r_send_cfg_en) ? i_status_addr:
                                                                r_tlp_address;
//assign  o_egress_tlp_requester_id           = (r_send_cfg_en) ? 16'h0:
//                                                                r_tlp_requester_id;

assign  o_egress_tlp_requester_id           = {i_pcie_bus_num, i_pcie_dev_num, i_pcie_fun_num};
assign  o_egress_tag                        = (r_send_cfg_en) ? 8'h0:
                                                                r_tlp_tag;


assign  r_cfg_ready                         = (cfg_state != IDLE);
assign  o_cfg_sm_state                      = cfg_state;
assign  o_sm_state                          = state;

assign  w_sts_ready                         = (state == IDLE);
assign  w_sts_hst_buf_stall                 = (state == WAIT_FOR_HOST_EGRESS_BUFFER)  ||
                                              (state == WAIT_FOR_HOST_INGRESS_BUFFER);
assign  w_sts_flg_fifo_stall                = (state == WAIT_FOR_FPGA_EGRESS_FIFO)    ||
                                              (state == WAIT_FOR_FPGA_INGRESS_FIFO);


assign  w_control_sm_idle                   = (state == IDLE)                     ||
                                              (state == EGRESS_DATA_FLOW)         ||
                                              (state == INGRESS_DATA_FLOW)        ||
                                              (state == SEND_CONFIG)              ||
                                              (state == SEND_CONFIG_SLEEP)        ||
                                              (state == WAIT_FOR_CONFIG)          ||
                                              (state == SEND_EGRESS_STATUS_SLEEP) ||
                                              (state == SEND_EGRESS_STATUS);

assign  w_config_sm_idle                    = (cfg_state == IDLE)           ||
                                              (cfg_state == PREPARE);

assign  w_valid_bus_select                  = (i_cmd_flg_sel_periph || i_cmd_flg_sel_memory || i_cmd_flg_sel_dma);

//synchronous logic
always @ (posedge clk) begin
  r_send_cfg_stb        <=  0;
  r_send_data_en        <=  0;

  if (rst || i_cmd_rst_stb) begin
    state               <=  IDLE;
    r_buf_rdy           <=  0;
    r_tlp_command       <=  0;
    r_tlp_flags         <=  0;
    r_tlp_address       <=  0;
    r_tlp_requester_id  <=  0;
    r_tlp_tag           <=  0;

    r_buf_done          <=  2'b00;

    o_data_write_flg    <=  0;
    o_data_read_flg     <=  0;

    o_data_fifo_flg     <=  0;
    o_per_sel           <=  0;
    o_mem_sel           <=  0;
    o_dma_sel           <=  0;

    r_sts_reset         <=  0;
    r_sts_done          <=  0;
    r_sts_cmd_err       <=  0;

    r_data_count        <=  0;
    r_block_count       <=  0;
    o_data_size         <=  0;
    o_data_address      <=  0;

    r_buf_sel           <=  0;
    r_buf_next_sel      <=  0;
    r_fifo_size         <=  0;

  end
  else begin
    case (state)
      IDLE: begin
        o_data_write_flg    <= 0;
        o_data_read_flg     <= 0;
        o_data_fifo_flg     <= 0;
        o_per_sel           <= 0;
        o_mem_sel           <= 0;
        o_dma_sel           <= 0;
        r_sts_reset         <= 0;
        r_sts_done          <= 0;
        r_sts_cmd_err       <= 0;
        r_tlp_tag           <= 0;
        r_buf_rdy           <= 0;

        r_data_count        <= 0;
        r_data_pos          <= 0;
        r_block_count       <= 0;
        r_buf_sel           <= 0;
        r_buf_next_sel      <= 0;

        o_data_address      <= i_cmd_data_address;
        o_data_size         <= i_cmd_data_count;

        if (i_cmd_wr_stb) begin
          if (w_valid_bus_select) begin
            o_data_write_flg<=  1;
            state           <=  INGRESS_DATA_FLOW;
          end
          else begin
            //XXX: SEND AN ERROR TELLING THE USER THEY NEED TO SELET A BUS
            r_sts_cmd_err   <=  1;
            state           <=  SEND_CONFIG;
          end
        end
        else if (i_cmd_rd_stb) begin
          if (w_valid_bus_select) begin
            o_data_read_flg      <=  1;
            state           <=  EGRESS_DATA_FLOW;
          end
          else begin
            //XXX: SEND AN ERROR TELLING THE USER THEY NEED TO SELET A BUS
            r_sts_cmd_err   <=  1;
            state           <=  SEND_CONFIG;
          end
        end
        //Flags
        if (i_cmd_flg_fifo) begin
          o_data_fifo_flg   <=  1;
        end
        if (i_cmd_flg_sel_periph) begin
          o_per_sel             <=  1;
        end
        if (i_cmd_flg_sel_memory) begin
          o_mem_sel             <=  1;
        end
        if (i_cmd_flg_sel_dma) begin
          o_dma_sel             <=  1;
        end
      end
      //Egress Flow
      EGRESS_DATA_FLOW: begin
        r_tlp_command                   <=  `PCIE_MWR_32B;
        r_tlp_flags                     <=  (`FLAG_NORMAL);
        if (r_data_count < o_data_size) begin
          //More data to send
          state                         <=  WAIT_FOR_HOST_EGRESS_BUFFER;
        end
        else begin
          r_sts_done                    <=  1;
          //r_buf_done                    <=  0;
          //state                         <=  SEND_CONFIG;
          state                         <=  IDLE;
        end
      end
      WAIT_FOR_HOST_EGRESS_BUFFER: begin
        if (w_config_sm_idle) begin
          r_block_count                 <=  0;
          //Select the next buffer
          if (r_buf_rdy > 0) begin
            if (r_buf_rdy == 2'b11) begin
              r_buf_sel                 <=  r_buf_next_sel;
              r_buf_next_sel            <=  ~r_buf_next_sel;  //Flip Flop the buffers
              r_buf_rdy[r_buf_next_sel] <=  0;
            end
            else if (r_buf_rdy == 2'b01) begin
              r_buf_next_sel            <=  1;                //Next time if there is a choice send the other
              r_buf_sel                 <=  0;
              r_buf_rdy[0]              <=  0;
            end
            else if (r_buf_rdy == 2'b10) begin
              r_buf_next_sel            <=  0;                //Next time if there is a choice send the other
              r_buf_sel                 <=  1;
              r_buf_rdy[1]              <=  0;
            end
            state                       <=  WAIT_FOR_FPGA_EGRESS_FIFO;
          end
        end
      end
      WAIT_FOR_FPGA_EGRESS_FIFO: begin
        //Send data to the host
        if ((r_data_count >= o_data_size) || (r_block_count >= i_buffer_size)) begin
          //De-assert the buffers
          r_buf_done[r_buf_sel]         <=  1;
          r_buf_sel                     <=  0;
          //Let the host know that we updated the data and buffer status
          r_send_cfg_stb                <=  1;
          if (r_data_count >= o_data_size) begin
            r_sts_done                  <=  1;
          end
          state                         <=  SEND_EGRESS_STATUS_SLEEP;
        end
        else if (i_e_fifo_rdy) begin
          r_fifo_size                   <=  i_e_fifo_size;
          r_tlp_address                 <=  read_buf_map[r_buf_sel] + r_block_count;
          state                         <=  SEND_EGRESS_DATA;
        end
      end
      SEND_EGRESS_DATA: begin
        //After a block of data is sent to the host send a configuration packet to update the buffer
        //Go back ot the 'egress data flow to start on the next block or see if we are done
        r_send_data_en                  <=  1;
        if (i_egress_finished) begin
          //Add the amount we sent through the egress FIFO to our data count
          r_block_count                 <=  r_block_count + (r_fifo_size << 2);
          r_data_count                  <=  r_data_count  + (r_fifo_size << 2);
          state                         <=  WAIT_FOR_FPGA_EGRESS_FIFO;
        end
      end
      SEND_EGRESS_STATUS_SLEEP: begin
        if (cfg_state != IDLE) begin
          state                         <=  SEND_EGRESS_STATUS;
        end
      end
      SEND_EGRESS_STATUS: begin
        if (cfg_state == IDLE) begin
          r_buf_done                    <=  0;
          r_data_pos                    <=  r_data_count;
          state                         <=  EGRESS_DATA_FLOW;
        end
      end




      //Ingress Flow
      INGRESS_DATA_FLOW: begin
        r_tlp_command                   <=  `PCIE_MRD_32B;
        r_tlp_flags                     <=  (`FLAG_NORMAL);
        if (r_data_count < o_data_size) begin
          //More data to send
        end
        else begin
          r_sts_done          <=  1;
          state               <=  SEND_CONFIG;
        end
      end
      WAIT_FOR_FPGA_INGRESS_FIFO: begin
      end
      WAIT_FOR_HOST_INGRESS_BUFFER: begin
      end
      WAIT_FOR_FLOW_CONTROL: begin
        //Config State Machine Idle
        if (w_config_sm_idle) begin
          state               <=  SEND_INGRESS_DATA;
        end
      end
      SEND_INGRESS_DATA: begin
        //At the end of a block send, send the updated buffer status to the host
        // go back to the 'Ingress data flow' to figure out if we need to read mroe data
        r_send_data_en        <=  1;
        if (i_egress_finished) begin
          r_data_count        <= r_data_count + 
          r_tlp_tag           <= r_tlp_tag + 1;
        end
      end





      //At the end of a transaction send the final status
      SEND_CONFIG: begin
        if(cfg_state == IDLE) begin
          //Send Config Strobe
          r_send_cfg_stb      <=  1;
          state               <=  WAIT_FOR_CONFIG;
        end
      end
      SEND_CONFIG_SLEEP: begin
        if (cfg_state != IDLE) begin
          state               <=  WAIT_FOR_CONFIG;
        end
      end
      WAIT_FOR_CONFIG: begin
        if (cfg_state == IDLE) begin
          state               <=  IDLE;
        end
      end
      default: begin
      end
    endcase
    if (i_update_buf_stb) begin
      r_buf_rdy          <=  r_buf_rdy | i_update_buf;
    end
    if (i_cmd_rst_stb) begin
      r_sts_reset             <=  1;
      state                   <=  SEND_CONFIG;
    end
  end
end

//This state machine has one purpose, to write the configuration data and send an interrupt
always @ (posedge clk) begin
  //Strobes
  r_fifo_stb                            <=  0;
  o_interrupt_stb                       <=  0;

  if (rst || i_cmd_rst_stb) begin
    cfg_state                           <=  IDLE;
    r_fifo_act                          <=  0;
    r_fifo_data                         <=  0;
    o_ctr_sel                           <=  0;
    r_fifo_count                        <=  0;
    r_send_cfg_en                       <=  0;
    o_interrupt_msi_value               <=  `NYSA_INTERRUPT_CONFIG;
    o_cfg_read_exec                     <=  0;

    r_sts_ping                          <=  0;
    r_sts_read_cfg                      <=  0;
    r_sts_interrupt                     <=  0;
    r_sts_unknown_cmd                   <=  0;
  end
  else begin
    case (cfg_state)
      IDLE: begin
        r_sts_ping                      <=  0;
        r_sts_read_cfg                  <=  0;
        r_sts_interrupt                 <=  0;
        r_sts_unknown_cmd               <=  0;

        r_fifo_count                    <=  0;
        o_ctr_sel                       <=  0;
        if (i_cmd_unknown) begin
          r_sts_unknown_cmd             <=  1;
        end
        if (i_cmd_ping_stb) begin
          cfg_state                     <=  PREPARE;
          r_sts_ping                    <=  1;
        end
        else if (i_cmd_rd_cfg_stb) begin
          cfg_state                     <=  PREPARE;
          r_sts_read_cfg                <=  1;
        end
        else if (r_send_cfg_stb) begin
          cfg_state                     <=  PREPARE;
        end
        else if (i_interrupt_stb) begin
          cfg_state                     <=  PREPARE;
          r_sts_interrupt               <=  1;
        end
      end
      PREPARE: begin
        if (w_control_sm_idle) begin
          o_ctr_sel                     <=  1;
          if ((w_fifo_rdy > 0) && (r_fifo_act == 0)) begin
            r_fifo_count                <=  0;
            if (w_fifo_rdy[0]) begin
              r_fifo_act[0]             <=  1;
            end
            else begin
              r_fifo_act[1]             <=  1;
            end
            cfg_state                   <=  LOAD_FIFO;
          end
        end
      end
      LOAD_FIFO: begin
        if (r_fifo_count < `CONFIG_REGISTER_COUNT) begin
          r_fifo_data                   <=  register_map[r_fifo_count];
          r_fifo_count                  <=  r_fifo_count + 1;
          r_fifo_stb                    <=  1;
        end
        else begin
          cfg_state                     <=  CFG_SEND_CONFIG;
          r_fifo_act                    <=  0;
          o_cfg_read_exec               <=  o_cfg_read_exec + 1;
        end
      end
      CFG_SEND_CONFIG: begin
        r_send_cfg_en                   <=  1;
        if (i_egress_finished) begin
          r_send_cfg_en                 <=  0;
          cfg_state                     <=  SEND_INT;
        end
      end
      SEND_INT: begin
        o_interrupt_stb                 <=  1;
        cfg_state                       <=  IDLE;
      end
      default: begin
        cfg_state                       <=  IDLE;
      end
    endcase
  end
end

endmodule
