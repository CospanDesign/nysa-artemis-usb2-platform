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
 * Author: David McCoy (dave.mccoy@cospandesign.com)
 * Description:
 *  Manages buffers for ingress transactions (Data sent from the host to FPGA)
 *  When the FPGA requests data from the host computer it makes a:
 *    Memory Read Request
 *  The request contains a tag and the count of dwords to receive (Among other
 *  things) The state machine that requests the data lets this cotnroller
 *  manage the actual tag and memory relationship. This controller follows the
 *  tag and through the following steps:
 *    * When the host says it has data available
 *    * The PCIE Control request to the host computer
 *    * The PCIE Ingress that receives data from the host and stores it into a
 *      local buffer
 *    * Buffer manager telling this controller that a FIFO has pulle the data
 *
 * Changes:
 *  4/30/2016: Initial Commit
 */

`define TAG_COUNT     4

//2048 / 4
//`define DWORD_COUNT   10'h0200
`define DWORD_COUNT   (2048 / 4)

module ingress_buffer_manager (
  input                     clk,
  input                     rst,

  //Host
  //input                     i_hst_buf_size,     //Size of buffer on host machine  (Probably not needed now but in future version it will be important)
  input                     i_hst_buf_rdy_stb,    //Strobe in the status of the buffer
  input         [1:0]       i_hst_buf_rdy,        //Reads in status of the buffer
  output  reg               o_hst_buf_fin_stb,    //Strobe to tell the PCIE Control FIFO we're done with buffer(s)
  output  reg   [1:0]       o_hst_buf_fin,        //Signals go high indicating that a buffer is finished

  //PCIE Control
  input                     i_ctr_en,             //PCIE Controller enables this state machine when starting a write
  input                     i_ctr_mem_rd_req_stb, //Strobe that commits a portion of the buffer
  output                    o_ctr_tag_rdy,        //Tell the controller that the tag is ready
  output        [7:0]       o_ctr_tag,            //Provide a tag for the PCIE Control to use
  output        [9:0]       o_ctr_dword_size,     //Provide the size of the packet

  //PCIE Ingress
  input                     i_ing_cplt_stb,       //Detect
  input         [7:0]       i_ing_cplt_tag,       //Tag that refereneces
  input         [11:0]      i_ing_cplt_byte_count,//When this reaches 0 the tag is finished
  input         [6:0]       i_ing_cplt_lwr_addr,  //Lower address when complete is broken up into multple packets

  //Buffer Builder
  output        [12:0]      o_bld_mem_addr,       //Address of where to start writing data
  output  reg   [1:0]       o_bld_buf_en,         //Tell Buffer Builder the FIFO can read the block data
  input                     i_bld_buf_fin         //Buffer Builder reported FIFO has read everything

);
//local parameters
localparam      IDLE                  = 4'h0;
localparam      WAIT_FOR_COMPLETION   = 4'h1;
localparam      FINISHED              = 4'h2;

//registes/wires
reg             [1:0]       r_buf_rdy;

reg             [3:0]       r_tag_rdy_pos;
reg             [3:0]       r_tag_rdy_cnt;
reg             [3:0]       r_tag_fin;


reg             [3:0]       r_tag_sm_en;
reg             [3:0]       r_tag_sm_fin;
wire            [31:0]      w_addr_map[0:3];


//Tag State
reg             [3:0]       tag_state[0:`TAG_COUNT];

//submodules
//asynchronous logic
assign  o_ctr_tag         = r_tag_rdy_pos;
assign  o_ctr_tag_rdy     = (r_tag_rdy_cnt > 0);


assign  w_addr_map[0]     = 31'h00000000;
assign  w_addr_map[1]     = 31'h00000800;
assign  w_addr_map[2]     = 31'h00001000;
assign  w_addr_map[3]     = 31'h00001800;

//Set the output block memory start address
assign  o_bld_mem_addr    = w_addr_map[i_ing_cplt_tag] + i_ing_cplt_lwr_addr;
assign  o_ctr_dword_size  = `DWORD_COUNT;

//synchronous logic

//Four stage management
//Host:           Sends buffer ready status
//    Problems:   I need to distinguish between the first and second packet
//PCIE Control:   Activates tag
//PCIE Ingress:   Detect Incomming Tag associated completion header provides address for writing data to buffer
//Buffer Builder: When the tags have written all the data, the PPFIFO needs to read a block, then block is done

//Buffer State Machine
integer x;
always @ (posedge clk) begin
  //De-assert Strobes
  o_hst_buf_fin_stb   <=  0;
  o_bld_buf_en        <=  0;

  if (rst || !i_ctr_en) begin
    r_tag_rdy_pos                 <=  0;
    r_tag_rdy_cnt                 <=  0;
    r_tag_sm_en                   <=  0;
    o_hst_buf_fin                 <=  0;
  end
  else begin

/* Host Control */

    //Handle Host Telling us it has buffers ready
    if (i_hst_buf_rdy_stb) begin
      //Only on an empty count do we need to move the position, otherwise
      //  the position is correctly associated with a tag
      if (r_tag_rdy_cnt  == 0) begin
        if (i_hst_buf_rdy[0]) begin
          r_tag_rdy_pos           <=  0;
        end
        else begin
          r_tag_rdy_pos           <=  2;
        end
      end
      r_tag_rdy_cnt               <=  r_tag_rdy_cnt + 2;
    end

/* PCIE Control - Tag Controller - PCIE Ingress */

    //The assignment statements tell the controller that we have a tag ready
    //  when the controller strobes us we decrement the count
    //  and increment the position
    if (i_ctr_mem_rd_req_stb) begin
      if (r_tag_rdy_cnt > 0) begin
        //This should never be false but just in case
        r_tag_rdy_cnt                 <=  r_tag_rdy_cnt - 1;
      end
      r_tag_sm_en[r_tag_rdy_pos]  <=  1;

      //Increment the position
      if (r_tag_rdy_pos == 2'h3) begin
        r_tag_rdy_pos             <=  0;
      end
      else begin
        r_tag_rdy_pos             <=  r_tag_rdy_pos + 1;
      end
    end

/* Completion Interface */

    //Tag State Machine Interface (When the tag state machine is finished it asserts r_tag_sm_fin[x])
    for (x = 0; x <  `TAG_COUNT; x = x + 1) begin
      if (r_tag_sm_en[x] && r_tag_sm_fin[x]) begin
        r_tag_sm_en[x]            <=  0;
        r_tag_fin[x]              <=  1;          //This Tag has finished it's job
      end
    end

/* Buffer Builder Controller */

    //Buffer Builder is waiting for the tag state machine to say we're done
    if (r_tag_fin[1:0] == 2'b11) begin
      //Tag state machine is finished, buffer builder has a complete packet, let it send the FIFO
      o_bld_buf_en[0]             <=  1;
      if (i_bld_buf_fin) begin
        //Buffer Builder has sent out the FIFO and is ready for new data
        //  reset everything and notify the control that we are ready For new data
        o_hst_buf_fin[0]          <=  1;
        r_tag_fin[1:0]            <=  2'b00;
        o_hst_buf_fin_stb         <=  1;
      end
    end
    if (r_tag_fin[3:2] == 2'b11) begin
      o_bld_buf_en[1]             <=  1;
      if (i_bld_buf_fin) begin
        o_hst_buf_fin[1]          <=  1;
        r_tag_fin[3:2]            <=  2'b00;
        o_hst_buf_fin_stb         <=  1;
      end
    end
  end
end


//Tag State Machine
genvar i;

generate
for (i = 0; i < `TAG_COUNT; i = i + 1) begin

always @ (posedge clk) begin
  r_tag_sm_fin[i]   <=  0;
  if (rst || !i_ctr_en) begin
    tag_state[i]    <=  IDLE;
    r_tag_sm_fin[i] <=  0;
  end
  else begin
    case (tag_state[i])
      IDLE: begin
        if (r_tag_sm_en[i]) begin
          tag_state[i]  <=  WAIT_FOR_COMPLETION;
        end
      end
      WAIT_FOR_COMPLETION: begin
        if (i_ing_cplt_stb && (i_ing_cplt_tag == i) && (i_ing_cplt_byte_count == 0)) begin
          //The tag completion strobe went off
          //The incomming tag matches one of our tags
          //The completion byte count == 0 (W'ere done!)
          tag_state[i]  <=  FINISHED;
        end
      end
      FINISHED: begin
        r_tag_sm_fin[i]     <=  1;
        if (!r_tag_sm_en[i]) begin
          tag_state[i]      <=  IDLE;
        end
      end
    endcase
  end
end

end
endgenerate




endmodule
