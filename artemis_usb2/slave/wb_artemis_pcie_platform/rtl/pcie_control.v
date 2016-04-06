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

module pcie_control (
  input                     clk,
  input                     rst,

  //Ingress Machine Interface
  input       [31:0]        i_write_a_addr,
  input       [31:0]        i_write_b_addr,
  input       [31:0]        i_read_a_addr,
  input       [31:0]        i_read_b_addr,
  input       [31:0]        i_status_addr,
  input       [31:0]        i_buffer_size,
  input       [31:0]        i_ping_value,
  input       [1:0]         i_update_buf,
  input                     i_update_buf_stb,

  input                     i_reg_write_stb,
  input       [3:0]         i_device_select,

  //In band reset
  input                     i_cmd_rst_stb,

  input                     i_cmd_wr_stb,
  input                     i_cmd_rd_stb,

  input                     i_cmd_flg_fifo,

  input                     i_cmd_ping_stb,
  input                     i_cmd_rd_cfg_stb,
  input                     i_cmd_unknown,

  input       [31:0]        i_cmd_data_count,
  input       [31:0]        i_cmd_data_address,

  //Buffer Controller

  //Flow Controller
  input                     i_pcie_fc_ready,

  //Egress State Machine
  output                    o_egress_enable,
  input                     i_egress_finished,
  output      [7:0]         o_egress_tlp_command,
  output      [13:0]        o_egress_tlp_flags,
  output      [31:0]        o_egress_tlp_address,
  output      [15:0]        o_egress_tlp_requester_id,
  output      [7:0]         o_egress_tag,

  //Egress FIFO for control data
  output  reg               o_egress_cntrl_fifo_select,
  output  reg               o_interrupt_msi_value,
  output  reg               o_interrupt_stb,

  output                    o_egress_fifo_rdy,
  input                     i_egress_fifo_act,
  output      [23:0]        o_egress_fifo_size,
  input                     i_egress_fifo_stb,
  output      [31:0]        o_egress_fifo_data,

  output                    o_sys_rst

);
//local parameters
localparam      IDLE            = 4'h0;
localparam      PROCESS         = 4'h1;


localparam      LOAD_FIFO       = 4'h2;
localparam      SEND_CONFIG     = 4'h3;
localparam      SEND_INT        = 4'h4;

//registes/wires

reg   [3:0]                 state;

wire  [1:0]                 w_fifo_rdy;
reg   [1:0]                 r_fifo_act;
wire  [23:0]                w_fifo_size;
reg                         r_fifo_stb;
reg   [31:0]                r_fifo_data;

reg   [4:0]                 r_fifo_count;

wire  [31:0]                register_map  [0:`CONFIG_REGISTER_COUNT];

reg   [1:0]                 r_buffer_ready;
reg                         r_send_data_en;

reg   [7:0]                 r_tlp_command;
reg   [13:0]                r_tlp_flags;
reg   [31:0]                r_tlp_address;
reg   [15:0]                r_tlp_requester_id;
reg   [7:0]                 r_tlp_tag;

//submodules
ppfifo #(
  .DATA_WIDTH       (32                 ),
  .ADDRESS_WIDTH    (4                  ) //32-bit data for register transfer
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
assign  register_map[`STATUS_BUF_ADDR]    = i_status_addr;
assign  register_map[`BUFFER_READY]       = {29'h00, r_buffer_ready};
assign  register_map[`WRITE_BUF_A_ADDR]   = i_write_a_addr;
assign  register_map[`WRITE_BUF_B_ADDR]   = i_write_b_addr;
assign  register_map[`READ_BUF_A_ADDR]    = i_read_a_addr;
assign  register_map[`READ_BUF_B_ADDR]    = i_read_b_addr;
assign  register_map[`BUFFER_SIZE]        = i_buffer_size;
assign  register_map[`PING_VALUE]         = i_ping_value;

assign  o_sys_rst                         = i_cmd_rst_stb;

assign  o_egress_enable                   = r_send_cfg_en || r_send_data_en;
assign  o_egress_tlp_command              = (r_send_cfg_en) ? `PCIE_MWR_32B:
                                                              r_tlp_command;

assign  o_egress_tlp_flags                = (r_send_cfg_en) ? (`FLAG_NORMAL):
                                                              r_tlp_flags;
assign  o_egress_tlp_address              = (r_send_cfg_en) ? i_status_addr:
                                                              r_tlp_address;
assign  o_egress_tlp_requester_id         = (r_send_cfg_en) ? 16'h0:
                                                              r_tlp_requester_id;
assign  o_egress_tag                      = (r_send_cfg_en) ? 8'h0:
                                                              r_tlp_tag;


assign  r_cfg_ready                       = (cfg_state != IDLE);
assign  r_data_sm_idle                    = ((state == IDLE) || (state == PROCESS));


//synchronous logic
always @ (posedge clk) begin
  r_send_int_stb        <=  0;

  if (rst || i_cmd_rst_stb) begin
    state               <=  IDLE;
    r_buffer_ready      <=  0;
    r_tlp_command       <=  0;
    r_tlp_flags         <=  0;
    r_tlp_address       <=  0;
    r_tlp_requester_id  <=  0;
    r_tlp_tag           <=  0;

  end
  else begin
    case (state)
      IDLE: begin
      end
      PROCESS: begin
        if (!r_cfg_ready) begin
        end
      end
      default: begin
      end
    endcase
    if (i_update_buf_stb) begin
      r_buffer_ready  <=  i_update_buf;
    end
  end
end

//Configuration State Machine
reg [3:0]     cfg_state;
wire          r_cfg_ready;
reg           r_send_int_stb;
reg           r_send_cfg_en;

//This state machine has one purpose, to write the configuration data and send an interrupt
always @ (posedge clk) begin
  //Strobes
  r_fifo_stb                            <=  0;
  o_interrupt_stb                       <=  0;

  if (rst || i_cmd_rst_stb) begin
    cfg_state                           <=  IDLE;
    r_fifo_act                          <=  0;
    r_fifo_data                         <=  0;
    o_egress_cntrl_fifo_select          <=  0;
    r_fifo_count                        <=  0;
    r_send_cfg_en                       <=  0;
    o_interrupt_msi_value               <=  `NYSA_INTERRUPT_CONFIG;
  end
  else begin
    case (cfg_state)
      IDLE: begin
        r_fifo_count                    <=  0;
        o_egress_cntrl_fifo_select      <=  0;
        if (i_cmd_ping_stb) begin
          cfg_state                     <=  PROCESS;
        end
        else if (i_cmd_rd_cfg_stb) begin
          cfg_state                     <=  PROCESS;
        end
        else if (r_send_int_stb) begin
          cfg_state                     <=  PROCESS;
        end
      end
      PROCESS: begin
        if (r_data_sm_idle) begin
          o_egress_cntrl_fifo_select    <=  1;
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
          cfg_state                     <=  SEND_CONFIG;
          r_fifo_act                    <=  0;
        end
      end
      SEND_CONFIG: begin
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
