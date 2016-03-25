/*
Distributed under the MIT license.
Copyright (c) 2016 Dave McCoy (dave.mccoy@cospandesign.com)

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
 * Author: Dave McCoy (dave.mccoy@cospandesign.com)
 * Description: Controls PCIE Bus by translating incomming commands
 *  from the AXI stream interface and then issuing:
 *  system:
 *    Commands
 *    Data Routing
 *    Host Requests
 *
 * Changes:
 *  3/23/2016: Initial Version
 */

`include "pcie_defines.v"

module pcie_controller (
  input                     clk,
  input                     rst

  input                     i_en,
  //System Controller

  //AXI Stream Input
  input                     i_axi_clk,
  output  reg               o_axi_ready,
  input       [31:0]        i_axi_data,
  input       [3:0]         i_axi_keep,
  input                     i_axi_last,
  input                     i_axi_valid,

  //AXI Stream Output
  output                    o_axi_clk,
  input                     i_axi_ready,
  output  reg [31:0]        o_axi_data,
  output      [3:0]         o_axi_keep,
  output  reg               o_axi_last,
  output  reg               o_axi_valid
);
//local parameters
localparam  IDLE                    = 4'h0;
localparam  READY                   = 4'h1;
localparam  READ_HDR                = 4'h2;
localparam  PROCESS                 = 4'h3;

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

//registes/wires
reg   [3:0]   state;
reg   [3:0]   r_hdr_index;

reg   [31:0]  r_hdr [0:3];

reg   [2:0]   r_hdr_size;
reg   [7:0]   r_hrd_cmd;
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
    `PCIE_CPLLK:            r_hdr_cmd = CMD_COMPLETE_LOCK
    `PCIE_CPLDLK:           r_hdr_cmd = CMD_COMPLETE_DATA_LOCK;
    `PCIE_FETCH_ADD:        r_hdr_cmd = CMD_FETCH_ADD;
    `PCIE_SWAP:             r_hdr_cmd = CMD_SWAP;
    `PCIE_CAS:              r_hdr_cmd = CMD_COMPARE_AND_SWAP;
    `PCIE_LPRF:             r_hdr_cmd = CMD_LPRF;
    `PCIE_EPRF:             r_hdr_cmd = CMD_EPRF;
    default:
  endcase
end

//synchronous logic

always @ (posedge clk) begin
  if (rst) begin
    state           <=  IDLE;
    o_axi_ready     <=  1'b0;
    r_hdr_index     <=  0;
  end
  else begin
    case (state)
      IDLE: begin
        if (i_en) begin
          state               <=  READY;
        end
      end
      READY: begin
        o_axi_ready           <=  1;
        r_hdr_index           <=  0;
        if (i_axi_valid) begin
          r_hdr[r_hdr_index]  <=  i_axi_data;
          r_hdr_index         <=  r_hdr_index + 1;
          state               <=  READ_HDR;
        end
      end
      READ_HDR: begin
        r_hdr[r_hdr_index]    <=  i_axi_data;
        r_hdr_index           <=  r_hdr_index + 1;
        if (r_hdr_index >= w_hdr_size - 1) begin
          //This will depend on the type of packet
          case (r_hdr_cmd) begin
            CMD_MEM_READ: begin
              //Prepare for a memory transfer
            end
            CMD_MEM_READ_LOCK: begin
              //Prepare for a memory transfer
            end
            CMD_MEM_WRITE: begin
              //Absorb the next 'length' of data and put it address
            end
            CMD_IO_READ: begin
              //Perform a simple IO read
            end
            CMD_IO_WRITE: begin
              //Perform a simple IO write
            end
            CMD_CONFIG_READD0: begin
              //XXX: Handled by PCIE Core
            end
            CMD_CONFIG_WRITE0: begin
              //XXX: Handled by PCIE Core
            end
            CMD_CONFIG_READ1: begin
              //XXX: Handled by PCIE Core
            end
            CMD_CONFIG_WRITE1: begin
              //XXX: Handled by PCIE Core
            end
            CMD_TCFGRD: begin
              //Depreciated, not supported
            end
            CMD_TCFGWR: begin
              //Depreciated, not supported
            end
            CMD_MESSAGE: begin
              //Out of BAR message
            end
            CMD_MESSAGE_DATA: begin
              //Out of BAR message with data
            end
            CMD_COMPLETE: begin
              //Response to a mem request initated by FPGA
            end
            CMD_COMPLETE_DATA: begin
              //Response to a mem request initated by FPGA with data
            end
            CMD_COMPLETE_LOCK
              //Response to a mem request initated by FPGA
            end
            CMD_COMPLETE_DATA_LOCK: begin
              //Response to a mem request initated by FPGA with data
            end
            CMD_FETCH_ADD: begin
              //Not Supported
            end
            CMD_SWAP: begin
              //Not Supported
            end
            CMD_COMPARE_AND_SWAP: begin
              //Not Supported
            end
            CMD_LPRF: begin
              //Not Supported
            end
            CMD_EPRF: begin
              //Not Supported
            default: begin
            end
          endcase
        end
      end
      default: begin
        state     <=  IDLE;
      end
    endcase
  end
end


endmodule
