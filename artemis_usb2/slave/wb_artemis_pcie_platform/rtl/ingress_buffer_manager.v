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

//2048 / 4
//`define DWORD_COUNT   10'h0200

module ingress_buffer_manager #(
  parameter                 BUFFER_WIDTH              = 12,   //4096
  parameter                 MAX_REQ_WIDTH             = 9
)(
  input                     clk,
  input                     rst,

  //Host
  //input                     i_hst_buf_size,     //Size of buffer on host machine  (Probably not needed now but in future version it will be important)
  input                     i_hst_buf_rdy_stb,    //Strobe in the status of the buffer
  input         [1:0]       i_hst_buf_rdy,        //Reads in status of the buffer
  output  reg               o_hst_buf_fin_stb,    //Strobe to tell the PCIE Control FIFO we're done with buffer(s)
  output  reg   [1:0]       o_hst_buf_fin,        //Signals go high indicating that a buffer is finished
  input                     i_hst_buf_fin_ack_stb,//PCIE Controller received the finished status

  //PCIE Control
  input                     i_ctr_en,             //PCIE Controller enables this state machine when starting a write
  input                     i_ctr_mem_rd_req_stb, //Strobe that commits a portion of the buffer
  output                    o_ctr_tag_rdy,        //Tell the controller that the tag is ready
  output        [7:0]       o_ctr_tag,            //Provide a tag for the PCIE Control to use
  output        [9:0]       o_ctr_dword_size,     //Provide the size of the packet
  output        [11:0]      o_ctr_start_addr,     //Provide the starting address (on host computer for this read)
  output  reg               o_ctr_buf_sel,        //Tell the PCIE controller what buffer we plan to use
  output                    o_ctr_idle,           //Tell the PCIE Control there are no outstanding transactions

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

localparam      MAX_REQ_SIZE          = 2 ** MAX_REQ_WIDTH;
localparam      BUFFER_SIZE           = 2 ** BUFFER_WIDTH;
localparam      BIT_FIELD_WIDTH       = 2 ** (BUFFER_WIDTH - MAX_REQ_WIDTH);
localparam      DWORD_COUNT           = MAX_REQ_SIZE / 4;
localparam      NUM_TAGS              = (BUFFER_SIZE / MAX_REQ_SIZE) * 2;
localparam      BUF0_POS              = 0;
localparam      BUF1_POS              = (NUM_TAGS / 2);
localparam      TAG0_BITFIELD         = (2 ** BUF1_POS) - 1;
localparam      TAG1_BITFIELD         = TAG0_BITFIELD << (BUF1_POS);

//registes/wires
reg             [1:0]               r_buf_rdy;
reg                                 r_start_control;

reg             [3:0]               r_tag_rdy_pos;
reg             [4:0]               r_tag_rdy_cnt;
reg             [NUM_TAGS - 1:0]    r_tag_fin;


reg             [NUM_TAGS - 1:0]    r_tag_sm_en;
reg             [NUM_TAGS - 1:0]    r_tag_sm_fin;
wire            [7:0]               w_tag_map[1:0];
wire            [NUM_TAGS - 1:0]    w_tag_bitfield[1:0];

wire            [1:0]               w_tag_ingress_done;


wire            [15:0]              w_tmp_bf        = BIT_FIELD_WIDTH;
wire            [15:0]              w_tmp_ttl_width = MAX_REQ_SIZE;
wire            [15:0]              w_tmp_buf_width = BUFFER_SIZE;
wire            [7:0]               w_max_tags      = NUM_TAGS;
wire            [7:0]               w_tag_map0;
wire            [7:0]               w_tag_map1;

wire            [NUM_TAGS - 1:0]    w_tag_bitfield0;
wire            [NUM_TAGS - 1:0]    w_tag_bitfield1;

//Tag State
reg             [3:0]               tag_state[0:NUM_TAGS];
reg             [12:0]              r_mem_offset[0:NUM_TAGS];

// DEBUG SIGNALS
wire            [3:0]               tag_state0;
wire            [3:0]               tag_state1;
wire            [3:0]               tag_state2;
wire            [3:0]               tag_state3;
wire            [3:0]               tag_state4;
wire            [3:0]               tag_state5;
wire            [3:0]               tag_state6;
wire            [3:0]               tag_state7;
wire            [3:0]               tag_state8;
wire            [3:0]               tag_state9;
wire            [3:0]               tag_state10;
wire            [3:0]               tag_state11;
wire            [3:0]               tag_state12;
wire            [3:0]               tag_state13;
wire            [3:0]               tag_state14;
wire            [3:0]               tag_state15;
// END DEBUG SIGNALS

//submodules
//asynchronous logic
assign  o_ctr_tag         = r_tag_rdy_pos;
assign  o_ctr_tag_rdy     = (r_tag_rdy_cnt > 0);

assign  w_tag_map0        = w_tag_map[0];
assign  w_tag_map1        = w_tag_map[1];

assign  w_tag_map[0]      = BUF0_POS;
assign  w_tag_map[1]      = BUF1_POS;

assign  o_ctr_start_addr  = o_ctr_tag << MAX_REQ_WIDTH;
assign  w_tag_bitfield[0] = TAG0_BITFIELD;
assign  w_tag_bitfield[1] = TAG1_BITFIELD;

assign  w_tag_bitfield0   = w_tag_bitfield[0];
assign  w_tag_bitfield1   = w_tag_bitfield[1];

assign  w_tag_ingress_done[0] = ((r_tag_sm_fin & w_tag_bitfield[0]) == (r_tag_sm_en & w_tag_bitfield[0]) &&
                                 (r_tag_sm_en & w_tag_bitfield[0]) > 0);
assign  w_tag_ingress_done[1] = ((r_tag_sm_fin & w_tag_bitfield[1]) == (r_tag_sm_en & w_tag_bitfield[1]) &&
                                 (r_tag_sm_en & w_tag_bitfield[1]) > 0);

//Set the output block memory start address
assign  o_bld_mem_addr    = (i_ing_cplt_tag << (MAX_REQ_WIDTH - 2)) + r_mem_offset[i_ing_cplt_tag];
//assign  o_bld_mem_addr    = (i_ing_cplt_tag << (MAX_REQ_WIDTH - 2));
assign  o_ctr_dword_size  = DWORD_COUNT;

assign  o_ctr_idle        = (r_tag_sm_en == 0);

// DEBUG SIGNALS
assign  tag_state0        = tag_state[0];
assign  tag_state1        = tag_state[1];
assign  tag_state2        = tag_state[2];
assign  tag_state3        = tag_state[3];
assign  tag_state4        = tag_state[4];
assign  tag_state5        = tag_state[5];
assign  tag_state6        = tag_state[6];
assign  tag_state7        = tag_state[7];
assign  tag_state8        = tag_state[8];
assign  tag_state9        = tag_state[9];
assign  tag_state10       = tag_state[10];
assign  tag_state11       = tag_state[11];
assign  tag_state12       = tag_state[12];
assign  tag_state13       = tag_state[13];
assign  tag_state14       = tag_state[14];
assign  tag_state15       = tag_state[15];
// END DEBUG SIGNALS

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
    o_hst_buf_fin                 <=  2'b11;
    o_ctr_buf_sel                 <=  0;
    r_start_control               <=  1;
    r_tag_fin                     <=  0;
  end
  else begin
    if (r_start_control) begin
      r_start_control             <=  0;
      o_hst_buf_fin_stb           <=  1;
    end
    if (i_hst_buf_fin_ack_stb) begin
      o_hst_buf_fin               <=  2'b00;
    end

/* Host Control */

    //Handle Host Telling us it has buffers ready
    if (i_hst_buf_rdy_stb) begin
      //Only on an empty count do we need to move the position, otherwise
      //  the position is correctly associated with a tag
      if (r_tag_rdy_cnt  == 0) begin
        if (i_hst_buf_rdy[0]) begin
          //r_tag_rdy_pos           <=  0;
          r_tag_rdy_pos           <=  w_tag_map[0];
          o_ctr_buf_sel           <=  0;
        end
        else begin
          //r_tag_rdy_pos           <=  2;
          r_tag_rdy_pos           <=  w_tag_map[1];
          o_ctr_buf_sel           <=  1;
        end
      end
      r_tag_rdy_cnt               <=  r_tag_rdy_cnt + 8;
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
      //if (r_tag_rdy_pos == 2'h3) begin
      if (r_tag_rdy_pos == (NUM_TAGS - 1)) begin
        r_tag_rdy_pos             <=  0;
        o_ctr_buf_sel             <=  0;
      end
      else begin
        r_tag_rdy_pos             <=  r_tag_rdy_pos + 1;
        if (r_tag_rdy_pos == (BUF1_POS - 1)) begin
          o_ctr_buf_sel           <=  1;
        end
      end
    end

/* Completion Interface */

    //Tag State Machine Interface (When the tag state machine is finished it asserts r_tag_sm_fin[x])
/*
    for (x = 0; x <  NUM_TAGS; x = x + 1) begin
      if (r_tag_sm_en[x] && r_tag_sm_fin[x]) begin
        r_tag_sm_en[x]            <=  0;
        r_tag_fin[x]              <=  1;          //This Tag has finished it's job
      end
    end
*/

/* Buffer Builder Controller */

    //Buffer Builder is waiting for the tag state machine to say we're done
    //if (((r_tag_sm_fin & w_tag_bitfield[0]) == (r_tag_sm_en & w_tag_bitfield[0])) > 0) begin
    if (w_tag_ingress_done[0] && !o_bld_buf_en[1]) begin
      //Tag state machine is finished, buffer builder has a complete packet, let it send the FIFO
      o_bld_buf_en[0]             <=  1;
      if (i_bld_buf_fin) begin
        //Buffer Builder has sent out the FIFO and is ready for new data
        //  reset everything and notify the control that we are ready For new data
        r_tag_fin                 <=  (r_tag_fin & w_tag_bitfield[1]);
        o_hst_buf_fin[0]          <=  1;
        o_hst_buf_fin_stb         <=  1;
        r_tag_sm_en               <=  r_tag_sm_en & ~TAG0_BITFIELD;
        r_tag_fin                 <=  r_tag_fin | TAG0_BITFIELD;
      end
    end
    else if (w_tag_ingress_done[1] && !o_bld_buf_en[0]) begin
    //else if (((r_tag_sm_fin & w_tag_bitfield[1]) == (r_tag_sm_en & w_tag_bitfield[1])) > 0) begin
      o_bld_buf_en[1]             <=  1;
      if (i_bld_buf_fin) begin
        r_tag_fin                 <=  (r_tag_fin & w_tag_bitfield[0]);
        o_hst_buf_fin[1]          <=  1;
        o_hst_buf_fin_stb         <=  1;
        r_tag_sm_en               <=  r_tag_sm_en & ~TAG1_BITFIELD;
        r_tag_fin                 <=  r_tag_fin | TAG1_BITFIELD;
      end
    end
  end
end

//Tag State Machine
genvar i;

generate
for (i = 0; i < NUM_TAGS; i = i + 1) begin : tag_sm

always @ (posedge clk) begin
  r_tag_sm_fin[i]   <=  0;
  if (rst || !i_ctr_en) begin
    tag_state[i]    <=  IDLE;
    r_tag_sm_fin[i] <=  0;
    r_mem_offset[i] <=  0;
  end
  else begin
    case (tag_state[i])
      IDLE: begin
        r_mem_offset[i] <=  0;
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
        else if (i_ing_cplt_stb && i_ing_cplt_tag == i) begin
          r_mem_offset[i]  <=  ((MAX_REQ_SIZE - i_ing_cplt_byte_count) >> 2);
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
