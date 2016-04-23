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

module  pcie_egress (
  input                     clk,
  input                     rst,

  input                     i_enable,
  output  reg               o_finished,
  input       [7:0]         i_command,
  input       [13:0]        i_flags,
  input       [31:0]        i_address,
  input       [15:0]        i_requester_id,
  input       [7:0]         i_tag,

  //AXI Stream Device 2 Host
  input                     i_axi_egress_ready,
  //output  reg [31:0]        o_axi_egress_data,
  output      [31:0]        o_axi_egress_data,
  output      [3:0]         o_axi_egress_keep,
  output  reg               o_axi_egress_last,
  output  reg               o_axi_egress_valid,

  //Outgoing FIFO Data
  input                     i_fifo_rdy,
  output  reg               o_fifo_act,
  input       [23:0]        i_fifo_size,
  input       [31:0]        i_fifo_data,
  output  reg               o_fifo_stb
);

//Local Parameters
localparam  IDLE                    = 4'h0;
localparam  WAIT_FOR_FIFO           = 4'h1;
localparam  WAIT_FOR_PCIE_CORE      = 4'h2;
localparam  SEND_HDR                = 4'h3;
localparam  SEND_DATA               = 4'h4;
localparam  FINISHED                = 4'h5;

//Registers/Wires
reg   [3:0]                 state;
reg   [23:0]                r_data_count;
wire  [31:0]                w_hdr[0:3];
wire  [2:0]                 w_hdr_size;
reg   [2:0]                 r_hdr_index;
wire  [9:0]                 w_pkt_data_count;

wire  [31:0]                w_hdr0;
wire  [31:0]                w_hdr1;
wire  [31:0]                w_hdr2;
wire  [31:0]                w_hdr3;
//Submodules
//Asynchronous Logic

assign  o_axi_egress_keep           = 4'hF;

//1st Dword
assign  w_hdr[0][`PCIE_TYPE_RANGE]          = i_command;
assign  w_hdr[0][`PCIE_FLAGS_RANGE]         = i_flags;
assign  w_hdr[0][`PCIE_DWORD_PKT_CNT_RANGE] = w_pkt_data_count;
assign  w_pkt_data_count  = (i_command == `PCIE_MRD_32B) ? 32'h0 : i_fifo_size;

//2nd Dword
assign  w_hdr[1]    =  (i_command == `PCIE_MRD_32B) ? {i_requester_id, i_tag, 8'h00} :
                          (i_fifo_size == 1)      ?   32'h0000000F :          //==  1 DWORD
                                                      32'h000000FF;           // >  1 DWORD
assign  w_hdr[2]    = i_address;
assign  w_hdr_size  = (w_hdr[0][29]) ?  3'h4 : 3'h3;  //Index Size is dependent on 64-bit vs 32-bit address space


assign  w_hdr0      = w_hdr[0];
assign  w_hdr1      = w_hdr[1];
assign  w_hdr2      = w_hdr[2];

assign  o_axi_egress_data = ((state == WAIT_FOR_PCIE_CORE) || (state == SEND_HDR)) ? w_hdr[r_hdr_index]:
                            i_fifo_data;

//Synchronous Logic
always @ (posedge clk) begin
  //Clear Strobes
  o_fifo_stb              <=  0;

  if (rst) begin
    state                 <=  IDLE;
    o_finished            <=  0;
    r_hdr_index           <=  0;
    o_axi_egress_valid    <=  0;
    o_axi_egress_last     <=  0;
    //o_axi_egress_data     <=  0;

    o_fifo_act            <=  0;
    r_data_count          <=  0;
  end
  else begin
    case (state)
      IDLE: begin
        o_axi_egress_valid<=  0;
        o_finished        <=  0;
        r_data_count      <=  0;
        r_hdr_index       <=  0;
        if (i_enable) begin
          state           <=  WAIT_FOR_FIFO;
        end
      end
      WAIT_FOR_FIFO: begin
        if (i_fifo_rdy && !o_fifo_act) begin
          r_data_count    <=  0;
          o_fifo_act      <=  1;
          state           <=  WAIT_FOR_PCIE_CORE;
          //o_axi_egress_data   <=  w_hdr[r_hdr_index];
          //r_hdr_index     <=  r_hdr_index + 1;
        end
      end
      WAIT_FOR_PCIE_CORE: begin
        if (i_axi_egress_ready && o_axi_egress_valid) begin
          r_hdr_index           <=  r_hdr_index + 1;
          if (r_hdr_index + 1 >= w_hdr_size) begin
            if (w_pkt_data_count == 0) begin
              o_axi_egress_last <=  1;
              state             <=  FINISHED;
            end
            else begin
              state             <=  SEND_DATA;
              o_fifo_stb        <=  1;
              r_data_count      <=  r_data_count + 1;
            end
          end
        end
        o_axi_egress_valid      <=  1;
      end
/*

      WAIT_FOR_PCIE_CORE: begin
        o_axi_egress_valid  <=  1;
        if (i_axi_egress_ready) begin
          //o_axi_egress_data <=  w_hdr[r_hdr_index];
          r_hdr_index       <=  r_hdr_index + 1;
          state             <=  SEND_HDR;
        end
      end
      SEND_HDR: begin
        //o_axi_egress_data   <=  w_hdr[r_hdr_index];
        r_hdr_index         <=  r_hdr_index + 1;
        if (r_hdr_index + 1 >= w_hdr_size) begin
          if (w_pkt_data_count == 0) begin
            o_axi_egress_last <=  1;
            state             <=  FINISHED;
          end
          else begin
            state             <=  SEND_DATA;
            o_fifo_stb        <=  1;
            r_data_count      <=  r_data_count + 1;
          end
        end
      end
*/
      SEND_DATA: begin
        //o_axi_egress_data   <=  i_fifo_data;
        o_fifo_stb          <=  1;
        if (r_data_count + 1 >= i_fifo_size) begin 
          state             <=  FINISHED;
          o_axi_egress_last <=  1;
        end
        r_data_count        <=  r_data_count + 1;
      end
      FINISHED: begin
        o_axi_egress_valid  <=  0;
        o_axi_egress_last   <=  0;
        o_fifo_act          <=  0;
        o_finished          <=  1;
        if (!i_enable) begin
          o_finished        <=  0;
          state             <=  IDLE;
        end
      end
      default: begin
        state           <=  IDLE;
      end
    endcase
  end
end
endmodule
