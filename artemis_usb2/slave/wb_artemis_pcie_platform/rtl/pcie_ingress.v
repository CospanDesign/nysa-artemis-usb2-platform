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

module pcie_ingress (
  input                     clk,
  input                     rst,

  //AXI Stream Host 2 Device
  input                     i_axi_ingress_clk,
  output  reg               o_axi_ingress_ready,
  input       [31:0]        i_axi_ingress_data,
  input       [3:0]         i_axi_ingress_keep,
  input                     i_axi_ingress_last,
  input                     i_axi_ingress_valid,

  //Parsed out control data
  output  reg [31:0]        o_write_a_addr,
  output  reg [31:0]        o_write_b_addr,
  output  reg [31:0]        o_read_a_addr,
  output  reg [31:0]        o_read_b_addr,
  output  reg [31:0]        o_status_addr,
  output  reg [31:0]        o_buffer_size,
  output  reg [31:0]        o_ping_value,
  output  reg [31:0]        o_update_buf,


  //Bar Hit
  input       [6:0]         i_bar_hit,
  input       [31:0]        i_control_addr_base,


  //Ingress Data Path
  input                     i_enable_data_path,

  output  reg               o_reg_write_stb,

  //Commands
  output  reg [3:0]         o_dev_sel,

  output  reg               o_cmd_rst_stb,
  output  reg               o_cmd_wr_stb,
  output  reg               o_cmd_rd_stb,
  output  reg               o_cmd_ping_stb,
  output  reg               o_cmd_rd_cfg_stb,
  output  reg               o_cmd_unknown,
  output  reg               o_flg_fifo,



  //Command Interface
  output  reg [31:0]        o_dword_size,

  //Buffer Interface
  input       [31:0]        i_buf_offset,
  input                     i_buf_rdy,
  output  reg               o_buf_we,
  output  reg [31:0]        o_buf_addr,
  output  reg [31:0]        o_buf_dat
);

//local parameters
localparam  IDLE                    = 4'h0;
localparam  READY                   = 4'h1;
localparam  READ_HDR                = 4'h2;
localparam  WRITE_REG               = 4'h3;
localparam  WRITE_CMD               = 4'h4;
localparam  READ_CMPLT              = 4'h5;
localparam  FLUSH                   = 4'h6;

//Commands
localparam  CMD_MEM_READ            = 8'h00;
localparam  CMD_MEM_READ_LOCK       = 8'h01;
localparam  CMD_MEM_WRITE           = 8'h02;
localparam  CMD_IO_READ             = 8'h03;
localparam  CMD_IO_WRITE            = 8'h04;
localparam  CMD_CONFIG_READD0       = 8'h05;
localparam  CMD_CONFIG_WRITE0       = 8'h06;
localparam  CMD_CONFIG_READ1        = 8'h07;
localparam  CMD_CONFIG_WRITE1       = 8'h08;
localparam  CMD_TCFGRD              = 8'h09;
localparam  CMD_TCFGWR              = 8'h0A;
localparam  CMD_MESSAGE             = 8'h0B;
localparam  CMD_MESSAGE_DATA        = 8'h0C;
localparam  CMD_COMPLETE            = 8'h0D;
localparam  CMD_COMPLETE_DATA       = 8'h0E;
localparam  CMD_COMPLETE_LOCK       = 8'h0F;
localparam  CMD_COMPLETE_DATA_LOCK  = 8'h10;
localparam  CMD_FETCH_ADD           = 8'h11;
localparam  CMD_SWAP                = 8'h12;
localparam  CMD_COMPARE_AND_SWAP    = 8'h13;
localparam  CMD_LPRF                = 8'h14;
localparam  CMD_EPRF                = 8'h15;
localparam  CMD_UNKNOWN             = 8'h16;




//registes/wires
reg   [3:0]                 state;
reg   [23:0]                r_data_count;
reg   [3:0]                 r_hdr_index;
reg   [31:0]                r_hdr [0:3];

reg   [2:0]                 r_hdr_size;
reg   [7:0]                 r_hdr_cmd;
wire  [9:0]                 w_pkt_data_size;
wire  [31:0]                w_pkt_addr;
wire  [31:0]                w_buf_pkt_addr_base;

wire  [31:0]                w_reg_addr;
wire                        w_cme_en;

reg   [31:0]                r_buf_cnt;
wire  [6:0]                 w_cmplt_lower_addr;


wire  [31:0]                w_hdr0;
wire  [31:0]                w_hdr1;
wire  [31:0]                w_hdr2;
wire  [31:0]                w_hdr3;

assign  w_hdr0        =    r_hdr[0];
assign  w_hdr1        =    r_hdr[1];
assign  w_hdr2        =    r_hdr[2];
assign  w_hdr3        =    r_hdr[3];

//submodules
//asynchronous logic
//Get Header Size
always @ (*) begin
  case (r_hdr[0][`PCIE_FMT_RANGE])
    `PCIE_FMT_3DW_NO_DATA:  r_hdr_size = 3;
    `PCIE_FMT_4DW_NO_DATA:  r_hdr_size = 4;
    `PCIE_FMT_3DW_DATA:     r_hdr_size = 3;
    `PCIE_FMT_4DW_DATA:     r_hdr_size = 4;
    default:                r_hdr_size = 0;
  endcase
end

always @ (*) begin
  casex (r_hdr[0][`PCIE_TYPE_RANGE])
    `PCIE_MRD:              r_hdr_cmd = CMD_MEM_READ;
    `PCIE_MRDLK:            r_hdr_cmd = CMD_MEM_READ_LOCK;
    `PCIE_MWR:              r_hdr_cmd = CMD_MEM_WRITE;
    `PCIE_IORD:             r_hdr_cmd = CMD_IO_READ;
    `PCIE_IOWR:             r_hdr_cmd = CMD_IO_WRITE;
    `PCIE_CFGRD0:           r_hdr_cmd = CMD_CONFIG_READD0;
    `PCIE_CFGWR0:           r_hdr_cmd = CMD_CONFIG_WRITE0;
    `PCIE_CFGRD1:           r_hdr_cmd = CMD_CONFIG_READ1;
    `PCIE_CFGWR1:           r_hdr_cmd = CMD_CONFIG_WRITE1;
    `PCIE_TCFGRD:           r_hdr_cmd = CMD_TCFGRD;
    `PCIE_TCFGWR:           r_hdr_cmd = CMD_TCFGWR;
    `PCIE_MSG:              r_hdr_cmd = CMD_MESSAGE;
    `PCIE_MSG_D:            r_hdr_cmd = CMD_MESSAGE_DATA;
    `PCIE_CPL:              r_hdr_cmd = CMD_COMPLETE;
    `PCIE_CPL_D:            r_hdr_cmd = CMD_COMPLETE_DATA;
    `PCIE_CPLLK:            r_hdr_cmd = CMD_COMPLETE_LOCK;
    `PCIE_CPLDLK:           r_hdr_cmd = CMD_COMPLETE_DATA_LOCK;
    `PCIE_FETCH_ADD:        r_hdr_cmd = CMD_FETCH_ADD;
    `PCIE_SWAP:             r_hdr_cmd = CMD_SWAP;
    `PCIE_CAS:              r_hdr_cmd = CMD_COMPARE_AND_SWAP;
    `PCIE_LPRF:             r_hdr_cmd = CMD_LPRF;
    `PCIE_EPRF:             r_hdr_cmd = CMD_EPRF;
    default:                r_hdr_cmd = CMD_UNKNOWN;
  endcase
end

assign  w_pkt_data_size       = r_hdr[0][`PCIE_DWORD_PKT_CNT_RANGE];
assign  w_pkt_addr            = r_hdr[2] >> 2;
assign  w_cmplt_lower_addr    = r_hdr[3][`CMPLT_LOWER_ADDR_RANGE];

assign  w_reg_addr            = (i_control_addr_base >= 0) ? (w_pkt_addr - i_control_addr_base): 32'h00;
assign  w_cmd_en              = (w_reg_addr > `CMD_OFFSET);
assign  w_buf_pkt_addr_base   = i_buf_offset - (w_pkt_addr + w_cmplt_lower_addr);

integer i;
//synchronous logic
always @ (posedge clk) begin
  o_reg_write_stb             <=  0;
  o_buf_we                    <=  0;

  o_cmd_rst_stb               <=  0;
  o_cmd_wr_stb                <=  0;
  o_cmd_rd_stb                <=  0;
  o_cmd_ping_stb              <=  0;
  o_cmd_rd_cfg_stb            <=  0;
  o_cmd_unknown               <=  0;
  o_flg_fifo                  <=  0;

  if (rst) begin
    state                     <=  IDLE;

    //Registers
    o_write_a_addr            <=  0;
    o_write_b_addr            <=  0;
    o_read_a_addr             <=  0;
    o_read_b_addr             <=  0;
    o_status_addr             <=  0;
    o_update_buf              <=  0;

    //Command Registers
    o_dword_size              <=  0;

    o_dev_sel                 <=  `SELECT_CONTROL;

    //Counts
    r_data_count              <=  0;
    r_hdr_index               <=  0;

    //Buffer Interface
    r_buf_cnt                 <=  0;
    o_buf_addr                <=  0;
    o_buf_dat                 <=  0;
    o_axi_ingress_ready       <=  0;

    for (i = 0; i < 4; i = i + 1) begin
      r_hdr[i]                <=  0;
    end
  end
  else begin
    case (state)
      IDLE: begin
        r_data_count          <=  0;

        if (i_axi_ingress_valid) begin
          if (i_bar_hit[0])begin
            //This is a config register or a new command
            state                     <=  READY;
          end
          else if (i_enable_data_path && i_buf_rdy) begin
            //We are reading data from the host computer
            state                     <=  READY;
          end
        end
      end
      READY: begin
        o_axi_ingress_ready           <=  1;
        r_hdr_index                   <=  0;
        r_hdr[r_hdr_index]            <=  i_axi_ingress_data;
        r_hdr_index                   <=  r_hdr_index + 1;
        state                         <=  READ_HDR;
      end
      READ_HDR: begin
        r_hdr[r_hdr_index]            <=  i_axi_ingress_data;
        r_hdr_index                   <=  r_hdr_index + 1;
        if (r_hdr_index + 1 >= r_hdr_size) begin
          case (r_hdr_cmd)
            CMD_MEM_WRITE: begin
              if (w_cmd_en) begin
                state                 <=  WRITE_CMD;
              end
              else begin
                state                 <=  WRITE_REG;
              end
            end
            CMD_COMPLETE_DATA: begin
              state                   <=  READ_CMPLT;
            end
            default: begin
              state                   <=  FLUSH;
            end
          endcase
        end
      end
      WRITE_REG: begin
        case (w_reg_addr)
          `STATUS_BUF_ADDR: begin
            o_status_addr             <=  i_axi_ingress_data;
          end
          `BUFFER_READY: begin
            o_update_buf              <=  i_axi_ingress_data[`BUFFER_READY_RANGE];
          end
          `WRITE_BUF_A_ADDR: begin
            o_write_a_addr            <=  i_axi_ingress_data;
          end
          `WRITE_BUF_B_ADDR: begin
            o_write_b_addr            <=  i_axi_ingress_data;
          end
          `READ_BUF_A_ADDR: begin
            o_read_a_addr             <=  i_axi_ingress_data;
          end
          `READ_BUF_B_ADDR: begin
            o_read_b_addr             <=  i_axi_ingress_data;
          end
          `BUFFER_SIZE: begin
            o_buffer_size             <=  i_axi_ingress_data;
          end
          default: begin
          end
        endcase
        o_reg_write_stb               <=  1;
        state                         <=  FLUSH;
      end
      WRITE_CMD: begin
        o_update_buf                  <=  2'b11;
        o_dword_size                  <=  i_axi_ingress_data;
        state                         <=  FLUSH;
        case (w_reg_addr)
          `COMMAND_RESET: begin
            o_dev_sel                       <=  `SELECT_CONTROL;
          end
          `PERIPHERAL_WRITE: begin
            o_dev_sel                       <=  `SELECT_PERIPH;
            o_cmd_wr_stb                    <=  1;
          end
          `PERIPHERAL_WRITE_FIFO: begin
            o_dev_sel                       <=  `SELECT_PERIPH;
            o_cmd_wr_stb                    <=  1;
            o_flg_fifo                      <=  1;
          end
          `PERIPHERAL_READ: begin
            o_cmd_rd_stb                    <=  1;
            o_dev_sel                       <=  `SELECT_PERIPH;
          end
          `PERIPHERAL_READ_FIFO: begin
            o_dev_sel                       <=  `SELECT_PERIPH;
            o_cmd_rd_stb                    <=  1;
            o_flg_fifo                      <=  1;
          end
          `MEMORY_WRITE: begin
            o_dev_sel                       <=  `SELECT_MEM;
            o_cmd_wr_stb                    <=  1;
          end
          `MEMORY_READ: begin
            o_dev_sel                       <=  `SELECT_MEM;
            o_cmd_rd_stb                    <=  1;
          end
          `DMA_WRITE: begin
            o_dev_sel                       <=  `SELECT_DMA;
            o_cmd_wr_stb                    <=  1;
          end
          `DMA_READ: begin
            o_dev_sel                       <=  `SELECT_DMA;
            o_cmd_rd_stb                    <=  1;
          end
          `PING: begin
            o_dev_sel                       <=  `SELECT_CONTROL;
            o_cmd_ping_stb                  <=  1;
            o_ping_value                    <=  i_axi_ingress_data;
          end
          `READ_CONFIG: begin
            o_dev_sel                       <=  `SELECT_CONTROL;
            o_cmd_rd_cfg_stb                <=  1;
          end
          default: begin
            o_dev_sel                       <=  `SELECT_CONTROL;
            o_cmd_unknown                   <=  1;
          end
        endcase
        state                         <=  FLUSH;
      end
      READ_CMPLT: begin
        //The Buffer is available
        if (r_buf_cnt < w_pkt_data_size) begin
          o_buf_addr                  <=  w_buf_pkt_addr_base + r_buf_cnt;
          o_buf_dat                   <=  i_axi_ingress_data;
          o_buf_we                    <=  1;
        end
        else begin
          state                       <=  FLUSH;
        end
      end
      FLUSH: begin
        if (!i_axi_ingress_valid) begin
          o_axi_ingress_ready         <=  0;
          state                       <=  IDLE;
        end
      end
      default: begin
        if (!i_axi_ingress_valid) begin
          o_axi_ingress_ready         <=  0;
          state                       <=  IDLE;
        end
      end
    endcase
  end
end



endmodule
