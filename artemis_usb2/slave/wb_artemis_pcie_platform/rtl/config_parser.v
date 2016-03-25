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
 * Description:
 *  Listens for configuration command updates.
 *  This will parse out configuration commands. Currently it only listens for
 *  a few specific configuration values including:
 *    -max payload size
 *    -BAR0 - 5 Addresses
 * Changes:
 *  3/24/2016: Initial Version
 */

`include "pcie_defines.v"

`define MAX_READ_COUNT 5

module config_parser (
  input                     rst,
  input                     clk,

  input                     i_en,

  // Host (CFG) Interface
  input       [31:0]        i_cfg_do,
  input                     i_cfg_rd_wr_done,
  output reg  [9:0]         o_cfg_dwaddr,
  output reg                o_cfg_rd_en,


  //AXI Stream Input

  output  reg [31:0]        o_bar_addr0,
  output  reg [31:0]        o_bar_addr1,
  output  reg [31:0]        o_bar_addr2,
  output  reg [31:0]        o_bar_addr3,
  output  reg [31:0]        o_bar_addr4,
  output  reg [31:0]        o_bar_addr5
);

//Local Parameters

localparam  IDLE          = 4'h0;
localparam  PREP_ADDR     = 4'h1;
localparam  WAIT_STATE    = 4'h2;
localparam  READ_DATA     = 4'h3;
localparam  READ_NEXT     = 4'h4;


//Registers/Wires
reg   [3:0]   state;
reg   [3:0]   index;
wire  [9:0]   w_cfg_addr[0:`MAX_READ_COUNT];

//Submodules
//Asynchronous Logic
//Get Header Size
assign  w_cfg_addr[0] = `BAR_ADDR0 >> 2;
assign  w_cfg_addr[1] = `BAR_ADDR1 >> 2;
assign  w_cfg_addr[2] = `BAR_ADDR2 >> 2;
assign  w_cfg_addr[3] = `BAR_ADDR3 >> 2;
assign  w_cfg_addr[4] = `BAR_ADDR4 >> 2;
assign  w_cfg_addr[5] = `BAR_ADDR5 >> 2;



//Synchronous Logic
always @ (posedge clk) begin
  o_cfg_rd_en         <=  0;
  if (rst) begin
    state             <=  IDLE;
    index             <=  0;

    o_cfg_dwaddr      <=  w_cfg_addr[0];

    o_bar_addr0       <=  0;
    o_bar_addr1       <=  0;
    o_bar_addr2       <=  0;
    o_bar_addr3       <=  0;
    o_bar_addr4       <=  0;
    o_bar_addr5       <=  0;
  end
  else begin
    case (state)
      IDLE: begin
        index             <=  0;
        if (i_en) begin
          state           <=  PREP_ADDR;
        end
      end
      PREP_ADDR: begin
        case (index)
          0: begin
            //o_cfg_dwaddr  <=  `BAR_ADDR0 >> 2;
            o_cfg_dwaddr  <=  4;
          end
          1: begin
            //o_cfg_dwaddr  <=  `BAR_ADDR1 >> 2;
            o_cfg_dwaddr  <=  5;
          end
          2: begin
            //o_cfg_dwaddr  <=  `BAR_ADDR2 >> 2;
            o_cfg_dwaddr  <=  6;
          end
          3: begin
            //o_cfg_dwaddr  <=  `BAR_ADDR3 >> 2;
            o_cfg_dwaddr  <=  7;
          end
          4: begin
            //o_cfg_dwaddr  <=  `BAR_ADDR4 >> 2;
            o_cfg_dwaddr  <=  8;
          end
          5: begin
            //o_cfg_dwaddr  <=  `BAR_ADDR5 >> 2;
            o_cfg_dwaddr  <=  9;
          end
        endcase
        state             <=  WAIT_STATE;
      end
      WAIT_STATE: begin
        o_cfg_rd_en       <=  1;
        if (i_cfg_rd_wr_done) begin
          state           <=  READ_DATA;
        end
      end
      READ_DATA: begin
        o_cfg_rd_en       <=  1;
        if (i_cfg_rd_wr_done) begin
          case (index)
            0: begin
              o_bar_addr0 <=  i_cfg_do;
            end
            1: begin
              o_bar_addr1 <=  i_cfg_do;
            end
            2: begin
              o_bar_addr2 <=  i_cfg_do;
            end
            3: begin
              o_bar_addr3 <=  i_cfg_do;
            end
            4: begin
              o_bar_addr4 <=  i_cfg_do;
            end
            5: begin
              o_bar_addr5 <=  i_cfg_do;
            end
            default: begin
            end
          endcase
          state           <=  READ_NEXT;
        end
      end
      READ_NEXT: begin
        if (!i_cfg_rd_wr_done) begin
          if (index < `MAX_READ_COUNT + 1) begin
            state         <=  PREP_ADDR;
            index         <=  index + 1;
          end
          else begin
            state         <=  IDLE;
          end
        end
      end
      default: begin
        state             <=  IDLE;
      end
    endcase
  end
end


endmodule
