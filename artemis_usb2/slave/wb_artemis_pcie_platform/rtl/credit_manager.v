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
 * Author: David McCoy (dave.mccoy@cospandesign.com)
 * Description:
 *  Manages credit from the PCIE Core to make sure the data requested will not
 *  be lost on the ingress
 *
 * Changes:
 *  4/29/2016: Initial Commit
 */

/* Credit:
 *
 *  Header Credit:
 *    either a 3 dword credit (for 32-bit data) or a 4 dword credit ( 64-bit data)
 *  Data Credit:
 *    16 byte chunk of data (4 x 32-bit)
 *
 */

/* Types of flow control
 *  000: Receive Buffer Available
 *  001: Receive Credits Granted to the link Partner
 *  010: Receive Credits Consumed
 *  100: Transmit User Credits Available
 *  101: Transmit Credit Limit
 *  110: Transmit Credit Consumed
 */

/* Max Receive Credit Size: 128 but divide by 4 because we are working with Dwords instead of Bytes*/
`define RCB_128_SIZE  (128 / 4)
`define RCB_64_SIZE   ( 64 / 4)

module credit_manager (
  input                     clk,
  input                     rst,


  //Credits/Configuration
  output        [2:0]       o_fc_sel,             //Select the type of flow control (see above)
  input                     i_rcb_sel,
  input         [7:0]       i_fc_cplh,            //Completion Header Credits
  input         [11:0]      i_fc_cpld,            //Completion Data Credits

  //PCIE Control Interface
  output  reg               o_ready,              //Ready for a new request
  input         [9:0]       i_dword_req_count,
  input                     i_cmt_stb,            //Controller commited this request

  //Completion Receive Size
  input         [9:0]       i_dword_rcv_count,
  input                     i_rcv_stb
);

//registes/wires

reg             [7:0]       r_hdr_in_flt;
reg             [11:0]      r_dat_in_flt;

wire                        w_hdr_rdy;
wire                        w_dat_rdy;
reg             [7:0]       r_max_hdr_req;

wire            [7:0]       w_hdr_avail;
wire            [11:0]      w_dat_avail;


reg             [7:0]       r_hdr_rcv_size;
reg                         r_delay_rcv_stb;

wire            [11:0]      w_data_credit_req_size;
wire            [11:0]      w_data_credit_rcv_size;


//submodules
//asynchronous logic
always @ (*) begin
  r_max_hdr_req = 0;
  //128 byte boundary
  if (i_rcb_sel) begin
    if (i_dword_req_count < `RCB_128_SIZE) begin
      r_max_hdr_req             =  1;
    end
    else begin
      r_max_hdr_req             =  i_dword_req_count[9:5];
    end
  end
  //64 byte boundary
  else begin
    if (i_dword_req_count < `RCB_64_SIZE) begin
      r_max_hdr_req             = 1;
    end
    else begin
      r_max_hdr_req             = i_dword_req_count[9:4];
    end
  end
end


always @ (*) begin
  r_hdr_rcv_size  = 0;
  //128 byte boundary
  if (i_rcb_sel) begin
    if (i_dword_rcv_count < `RCB_128_SIZE) begin
      r_hdr_rcv_size            = 1;
    end
    else begin
      r_hdr_rcv_size            =  i_dword_rcv_count[9:5];
    end
  end
  //64 byte boundary
  else begin
    if (i_dword_rcv_count < `RCB_64_SIZE) begin
      r_hdr_rcv_size            = 1;
    end
    else begin
      r_hdr_rcv_size            =  i_dword_rcv_count[9:4];
    end
  end
end

assign  w_data_credit_req_size  = (i_dword_req_count[9:2] == 0) ? 10'h1  : i_dword_req_count[9:2];
assign  w_data_credit_rcv_size  = (i_dword_rcv_count[9:2] == 0) ? 10'h1  : i_dword_rcv_count[9:2];

assign  w_hdr_avail             = (i_fc_cplh - r_hdr_in_flt);
assign  w_dat_avail             = (i_fc_cpld - r_dat_in_flt);

assign  w_hdr_rdy               = (w_hdr_avail > r_max_hdr_req);
assign  w_dat_rdy               = (w_dat_avail > w_data_credit_req_size);

assign  o_fc_sel                = 3'h0;

//synchronous logic
always  @ (posedge clk) begin
  r_delay_rcv_stb               <=  0;
  if (rst) begin
    r_hdr_in_flt                <=  0;
    r_dat_in_flt                <=  0;
  end
  else begin
    if (i_cmt_stb) begin
      r_hdr_in_flt              <=  r_hdr_in_flt + r_max_hdr_req;
      r_dat_in_flt              <=  r_dat_in_flt + w_data_credit_req_size;
      //This extremely RARE situtation where the receive and commit strobe happened at the same time
      if (i_rcv_stb) begin
        r_delay_rcv_stb         <=  1;
      end
    end
    else if (i_rcv_stb || r_delay_rcv_stb) begin
      r_hdr_in_flt              <=  r_hdr_in_flt - r_hdr_rcv_size;
      r_dat_in_flt              <=  r_dat_in_flt - w_data_credit_rcv_size;
    end
  end
end


endmodule
