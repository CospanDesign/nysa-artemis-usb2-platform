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

`timescale 1ps / 1ps


`define FLAG_DMA_BUS    16'h0004
`define FLAG_MEM_DMA_R  16'h0008


`define PERIPH_CHANNEL  0
`define MEMORY_CHANNEL  1
`define DMA_CHANNEL     2

module riffa_host_interface (
  input                     clk,
  input                     rst,

  output  reg [31:0]        o_mem_adr,
  output  reg [31:0]        o_dma_adr ,
  output  reg               o_mem_write_en,
  output  reg               o_mem_read_en,

  input       [1:0]         i_riffa_ingress_sel,
  output  reg [1:0]         o_riffa_egress_sel,

  //Ingress (From Host)
  input                     i_per_iriffa_en,
  output  reg               o_per_iriffa_ack,
  input                     i_per_iriffa_last,
  input       [31:0]        i_per_iriffa_len,
  input       [30:0]        i_per_iriffa_off,
  input       [31:0]        i_per_iriffa_data,
  input                     i_per_iriffa_data_valid,
  output  reg               o_per_iriffa_data_ren,

  //Egress (to host)
  output  reg               o_per_eriffa_en,
  input                     i_per_eriffa_ack,
  output  reg               o_per_eriffa_last,
  output  reg [31:0]        o_per_eriffa_len,
  output  reg [30:0]        o_per_eriffa_off,
  output  reg [31:0]        o_per_eriffa_data,
  output  reg               o_per_eriffa_data_valid,
  input                     i_per_eriffa_data_ren,

  //Mem Ingress (From Host)
  input                     i_mem_iriffa_en,
  output  reg               o_mem_iriffa_ack,
  input                     i_mem_iriffa_last,
  input       [31:0]        i_mem_iriffa_len,
  input       [30:0]        i_mem_iriffa_off,
  input       [31:0]        i_mem_iriffa_data,
  input                     i_mem_iriffa_data_valid,
  output  reg               o_mem_iriffa_data_ren,

  //Mem Egress (to host)
  output                    o_mem_eriffa_en,
  input                     i_mem_eriffa_ack,
  output                    o_mem_eriffa_last,
  output      [31:0]        o_mem_eriffa_len,
  output      [30:0]        o_mem_eriffa_off,
  output      [31:0]        o_mem_eriffa_data,
  output                    o_mem_eriffa_data_valid,
  input                     i_mem_eriffa_data_ren,

  //DMA Ingress (From Host)
  input                     i_dma_iriffa_en,
  output  reg               o_dma_iriffa_ack,
  input                     i_dma_iriffa_last,
  input       [31:0]        i_dma_iriffa_len,
  input       [30:0]        i_dma_iriffa_off,
  input       [31:0]        i_dma_iriffa_data,
  input                     i_dma_iriffa_data_valid,
  output  reg               o_dma_iriffa_data_ren,

  //DMA Egress (to host)
  output                    o_dma_eriffa_en,
  input                     i_dma_eriffa_ack,
  output                    o_dma_eriffa_last,
  output      [31:0]        o_dma_eriffa_len,
  output      [30:0]        o_dma_eriffa_off,
  output      [31:0]        o_dma_eriffa_data,
  output                    o_dma_eriffa_data_valid,
  input                     i_dma_eriffa_data_ren,

  input       [1:0]         i_mem_ingress_rdy,
  input       [23:0]        i_mem_ingress_size,
  output  reg [1:0]         o_mem_ingress_act,
  output  reg               o_mem_ingress_stb,
  output  reg [31:0]        o_mem_ingress_data,

  input                     i_mem_egress_rdy,
  input       [23:0]        i_mem_egress_size,
  output                    o_mem_egress_act,
  output                    o_mem_egress_stb,
  input       [31:0]        i_mem_egress_data,

  input       [1:0]         i_dma_ingress_rdy,
  input       [23:0]        i_dma_ingress_size,
  output  reg [1:0]         o_dma_ingress_act,
  output  reg               o_dma_ingress_stb,
  output  reg [31:0]        o_dma_ingress_data,

  input                     i_dma_egress_rdy,
  input       [23:0]        i_dma_egress_size,
  output                    o_dma_egress_act,
  output                    o_dma_egress_stb,
  input       [31:0]        i_dma_egress_data,


  //Input Path
  input                     i_master_ready,
  output  reg               o_ready,
  output      [31:0]        o_command,
  output      [31:0]        o_address,
  output  reg [31:0]        o_data,
  output      [27:0]        o_data_count,
  output                    o_ih_rst,

  //Output Path
  output  reg               o_out_ready,
  input                     i_en,
  input       [31:0]        i_status,
  input       [31:0]        i_address,
  input       [31:0]        i_data,
  input       [27:0]        i_data_count


);
//local parameters
localparam  IDLE                            = 5'h00;
localparam  PREPARE_PERIPH_INGRESS          = 5'h01;
localparam  PARSE_PERIPH_COMMAND            = 5'h02;
localparam  READ_PERIPH_DATA_FROM_FIFO      = 5'h03;
localparam  SEND_PERIPH_DATA_TO_MASTER      = 5'h04;
localparam  REQUEST_PERIPH_DATA_FROM_MASTER = 5'h05;
localparam  READ_PERIPH_STATUS_FROM_MASTER  = 5'h06;
localparam  WAIT_FOR_MEM_INGRESS            = 5'h08;
localparam  PREPARE_MEM_INGRESS_PPFIFO      = 5'h09;
localparam  SEND_MEM_EGRESS_DATA            = 5'h0A;
localparam  WRITE_MEM_DATA                  = 5'h0B;
localparam  WAIT_FOR_DMA_INGRESS            = 5'h0C;
localparam  SEND_DMA_EGRESS_DATA            = 5'h0D;
localparam  PREPARE_DMA_PPFIFO              = 5'h0E;
localparam  WRITE_DMA_DATA                  = 5'h0F;
localparam  PREPARE_PERIPH_EGRESS           = 5'h10;
localparam  PREPARE_PERIPH_EGRESS_DATA      = 5'h11;
localparam  SEND_PERIPH_EGRESS_DATA         = 5'h12;
localparam  FLUSH                           = 5'h13;
localparam  FLUSH_OUTPUT                    = 5'h14;
localparam  FINISHED                        = 5'h15;

localparam  PERIPH_HDR_COUNT                = 3;
localparam  RESP_HDR_COUNT                  = 4;


//registes/wires
reg           [4:0]         state;
reg           [31:0]        count;
reg           [31:0]        r_fifo_pos;
reg           [31:0]        r_fifo_size;

reg           [31:0]        r_hdr[3:0];

reg           [31:0]        r_resp[3:0];
reg           [31:0]        r_out_data;
wire          [31:0]        w_out_data_count;

wire          [15:0]        w_flags;

wire          [15:0]        w_status_command;

reg                         r_mem_egress_en;
wire                        w_mem_egress_fin;
reg           [31:0]        r_mem_egress_length;

reg                         r_dma_egress_en;
wire                        w_dma_egress_fin;
reg           [31:0]        r_dma_egress_length;




assign  w_out_data_count  = r_resp[1];


assign  o_command         = r_hdr[0];
assign  o_data_count      = r_hdr[1];
assign  o_address         = r_hdr[2];


assign  w_flags           = o_command[31:16];
assign  w_status_command  = ~i_status[15:0];

integer i;
integer j;

//submodules
adapter_ppfifo_2_riffa mem_p2r (
  .clk                (clk                      ),
  .rst                (rst                      ),

  .i_en               (r_mem_egress_en          ),
  .o_fin              (w_mem_egress_fin         ),
  .i_length           (r_mem_egress_length      ),

  .i_ppfifo_rdy       (i_mem_egress_rdy         ),
  .o_ppfifo_act       (o_mem_egress_act         ),
  .i_ppfifo_size      (i_mem_egress_size        ),
  .i_ppfifo_data      (i_mem_egress_data        ),
  .o_ppfifo_stb       (o_mem_egress_stb         ),

  .o_riffa_en         (o_mem_eriffa_en          ),
  .i_riffa_ack        (i_mem_eriffa_ack         ),
  .o_riffa_last       (o_mem_eriffa_last        ),
  .o_riffa_len        (o_mem_eriffa_len         ),
  .o_riffa_off        (o_mem_eriffa_off         ),
  .o_riffa_data       (o_mem_eriffa_data        ),
  .o_riffa_data_valid (o_mem_eriffa_data_valid  ),
  .i_riffa_data_ren   (i_mem_eriffa_data_ren    )
);

adapter_ppfifo_2_riffa dma_p2r (
  .clk                (clk                      ),
  .rst                (rst                      ),

  .i_en               (r_dma_egress_en          ),
  .o_fin              (w_dma_egress_fin         ),
  .i_length           (r_dma_egress_length      ),

  .i_ppfifo_rdy       (i_dma_egress_rdy         ),
  .o_ppfifo_act       (o_dma_egress_act         ),
  .i_ppfifo_size      (i_dma_egress_size        ),
  .i_ppfifo_data      (i_dma_egress_data        ),
  .o_ppfifo_stb       (o_dma_egress_stb         ),

  .o_riffa_en         (o_dma_eriffa_en          ),
  .i_riffa_ack        (i_dma_eriffa_ack         ),
  .o_riffa_last       (o_dma_eriffa_last        ),
  .o_riffa_len        (o_dma_eriffa_len         ),
  .o_riffa_off        (o_dma_eriffa_off         ),
  .o_riffa_data       (o_dma_eriffa_data        ),
  .o_riffa_data_valid (o_dma_eriffa_data_valid  ),
  .i_riffa_data_ren   (i_dma_eriffa_data_ren    )
);

//asynchronous logic
//synchronous logic
always @ (posedge clk) begin
  o_mem_ingress_stb       <=  0;

  o_dma_ingress_stb       <=  0;


  o_out_ready             <=  0;
  o_ready                 <=  0;
  o_per_iriffa_ack           <=  0;
  o_mem_iriffa_ack           <=  0;
  o_dma_iriffa_ack           <=  0;

  if (rst) begin
    o_per_iriffa_data_ren    <=  0;
    o_mem_iriffa_data_ren    <=  0;
    o_dma_iriffa_data_ren    <=  0;

    o_riffa_egress_sel        <=  0;

    o_per_eriffa_en           <=  0;
    o_per_eriffa_last         <=  0;
    o_per_eriffa_len          <=  0;
    o_per_eriffa_off          <=  0;
    o_per_eriffa_data         <=  0;
    o_per_eriffa_data_valid   <=  0;

    o_mem_ingress_act     <=  0;
    o_mem_ingress_data    <=  0;

    o_dma_ingress_act     <=  0;
    o_dma_ingress_data    <=  0;


    o_mem_adr             <=  0;
    o_mem_write_en        <=  0;
    o_mem_read_en         <=  0;
    o_dma_adr             <=  0;
    o_data                <=  0;

    state                 <=  IDLE;
    count                 <=  0;
    r_fifo_size           <=  0;
    r_fifo_pos            <=  0;
    r_out_data            <=  0;

    r_mem_egress_en       <=  0;
    r_mem_egress_length   <=  0;


    r_dma_egress_en       <=  0;
    r_dma_egress_length   <=  0;


    for (i = 0; i < RESP_HDR_COUNT; i = i + 1) begin
      r_resp[i]           <=  0;
    end
    for (j = 0; j < PERIPH_HDR_COUNT; j = j + 1) begin
      r_hdr[j]            <=  0;
    end

  end
  else begin
    case (state)
      IDLE: begin
        o_out_ready             <=  1;
        o_per_eriffa_en         <=  0;
        o_per_eriffa_last       <=  0;
        o_per_eriffa_len        <=  0;
        o_per_eriffa_off        <=  0;
        o_per_eriffa_data       <=  0;
        o_per_eriffa_data_valid <=  0;
        r_fifo_pos              <=  0;
        o_mem_write_en          <=  0;
        o_mem_read_en           <=  0;

        r_mem_egress_en         <=  0;
        r_mem_egress_length     <=  0;

        r_dma_egress_en         <=  0;
        r_dma_egress_length     <=  0;

        count                   <=  0;

        if (!i_en) begin
          r_resp[0]             <=  i_status;
          r_resp[1]             <=  i_data_count;
          r_resp[2]             <=  i_address;
          r_resp[3]             <=  i_data;
        end

        //Determine if there is a new request from the host
        if (i_per_iriffa_en) begin
          r_fifo_size       <=  i_per_iriffa_len;
          o_per_iriffa_ack     <=  1;
          case (i_riffa_ingress_sel)
            `PERIPH_CHANNEL: begin
              state         <=  PREPARE_PERIPH_INGRESS;
            end
            `MEMORY_CHANNEL: begin
              state         <=  PREPARE_MEM_INGRESS_PPFIFO;
            end
            `DMA_CHANNEL: begin
              state         <=  PREPARE_DMA_PPFIFO;
            end
            default: begin
            end
          endcase
        end
        else if (i_en) begin
          o_out_ready     <=  0;
          count           <=  0;
          r_out_data      <=  i_data;

          //Data is comming from the master
          case (w_status_command)
            `COMMAND_WRITE: begin
              state         <= FLUSH_OUTPUT;
            end
            `COMMAND_READ: begin
              state         <=  PREPARE_PERIPH_EGRESS;
            end
            `COMMAND_RESET: begin
              state         <= FLUSH_OUTPUT;
            end
            `COMMAND_MASTER_ADDR: begin
              state         <= FLUSH_OUTPUT;
            end
            `COMMAND_CORE_DUMP: begin
              state         <= FLUSH_OUTPUT;
            end
            `COMMAND_PING: begin
              state         <=  PREPARE_PERIPH_EGRESS;
            end
            default: begin
              state         <= FLUSH_OUTPUT;
            end
          endcase
        end
      end
      PREPARE_PERIPH_INGRESS: begin

        if (count < r_fifo_size)begin
          o_per_iriffa_data_ren      <=  1;
        end
        else begin
          o_per_iriffa_data_ren      <=  0;
          state                   <=  PARSE_PERIPH_COMMAND;
        end


        if (o_per_iriffa_data_ren && i_per_iriffa_data_valid) begin
          count                   <=  count + 1;
          if (count >= PERIPH_HDR_COUNT - 1) begin
            o_per_iriffa_data_ren    <=  0;
          end
        end


        //Grab the Header Count
        if (count < PERIPH_HDR_COUNT) begin
          if (o_per_iriffa_data_ren && i_per_iriffa_data_valid) begin
            r_hdr[count]          <=  i_per_iriffa_data;
          end
        end
        else begin
          o_per_iriffa_data_ren      <=  0;
          state                   <=  PARSE_PERIPH_COMMAND;
        end
      end
      PARSE_PERIPH_COMMAND: begin

        //The host will always send down at least three words
        //Command
        //Data Count
        //Address

        //If write perpheral then start sending down data
        //If write memory or dma then this is the end of the packet (data is sent down on another channel)
        //If this is a read this is the end of the packet
        //If this is a Ping then send the request to the master
        case (o_command[15:0])
          `COMMAND_PING: begin
            //Not Supported right now
            state                 <=  FLUSH;
          end
          `COMMAND_WRITE: begin
            if (w_flags & `FLAG_MEM_BUS) begin
              o_mem_adr           <=  o_address;
              if (w_flags & `FLAG_MEM_DMA_R) begin
                o_riffa_egress_sel<=  `MEMORY_CHANNEL;
                o_mem_read_en     <=  1;
                state             <=  SEND_MEM_EGRESS_DATA;
              end
              else begin
                o_mem_write_en    <=  1;
                state             <=  WAIT_FOR_MEM_INGRESS;
              end
            end
            else if (w_flags & `FLAG_DMA_BUS) begin
              o_dma_adr           <=  o_address;
              if (w_flags & `FLAG_MEM_DMA_R) begin
                o_riffa_egress_sel<=  `DMA_CHANNEL;
                state             <=  SEND_DMA_EGRESS_DATA;
              end
              else begin
                state             <=  WAIT_FOR_DMA_INGRESS;
              end
            end
            else begin
              state               <=  READ_PERIPH_DATA_FROM_FIFO;
            end
          end
          `COMMAND_READ: begin
            o_riffa_egress_sel    <=  `PERIPH_CHANNEL;
            state                 <=  REQUEST_PERIPH_DATA_FROM_MASTER;
          end
          `COMMAND_RESET: begin
            //Not Supported right now
            state                 <=  FLUSH;
          end
          `COMMAND_MASTER_ADDR: begin
            //Not Supported right now
            state                 <=  FLUSH;
          end
          `COMMAND_CORE_DUMP: begin
            //Not Supported right now
            state                 <=  FLUSH;
          end
          default: begin
          end
        endcase
      end
      READ_PERIPH_DATA_FROM_FIFO: begin
        o_ready                   <=  0;
        if (count < r_fifo_size) begin
          o_per_iriffa_data_ren      <=  1;
          if (o_per_iriffa_data_ren && i_per_iriffa_data_valid) begin
            count                   <=  count + 1;
            o_data                  <=  i_per_iriffa_data;
            o_ready                 <=  1;
            o_per_iriffa_data_ren      <=  0;
            state                   <=  SEND_PERIPH_DATA_TO_MASTER;
          end
        end
        else begin
          state                     <=  FINISHED;
        end
      end
      SEND_PERIPH_DATA_TO_MASTER: begin
        o_ready                     <=  1;
        if (i_master_ready) begin
          o_ready                   <=  0;
          state                     <=  READ_PERIPH_DATA_FROM_FIFO;
        end
      end
      REQUEST_PERIPH_DATA_FROM_MASTER: begin
        if (i_master_ready) begin
          o_ready                   <=  1;
          //state                     <=  READ_PERIPH_DATA_FROM_MASTER;
          state                     <=  IDLE;
        end
      end
      READ_PERIPH_STATUS_FROM_MASTER: begin
        o_out_ready                 <=  1;
        if (i_en) begin
          state                     <=  PREPARE_PERIPH_EGRESS;
        end
      end
      WAIT_FOR_MEM_INGRESS: begin
        if (i_mem_iriffa_en) begin
          o_mem_iriffa_ack             <=  1;
          state                     <=  PREPARE_MEM_INGRESS_PPFIFO;
          r_fifo_size               <=  i_mem_iriffa_len;
          r_fifo_pos                <=  0;
        end
      end
      PREPARE_MEM_INGRESS_PPFIFO: begin
        //This only happens when we are writing data to memory
        //Grab a memory PPFIFO
        //Need to grab a PPFIFO for memory
        if ((i_mem_ingress_rdy > 0) && (o_mem_ingress_act == 0)) begin
          count                     <=  0;
          if (i_mem_ingress_rdy[0]) begin
            o_mem_ingress_act[0]    <=  1;
          end
          else begin
            o_mem_ingress_act[1]    <=  1;
          end
          state                     <=  WRITE_MEM_DATA;
        end
      end
      WRITE_MEM_DATA: begin
        if (r_fifo_pos < r_fifo_size) begin
          if (count < i_mem_ingress_size) begin
            o_mem_iriffa_data_ren      <=  1;
            if (o_mem_iriffa_data_ren && i_mem_iriffa_data_valid) begin
              count                 <=  count + 1;
              r_fifo_pos            <=  r_fifo_pos + 1;
              o_mem_ingress_data    <=  i_mem_iriffa_data;
              o_mem_ingress_stb     <=  1;
            end
            if (count >= (i_mem_ingress_size - 1)) begin
              o_mem_iriffa_data_ren    <=  0;
            end
          end
          else begin
            o_mem_ingress_act         <=  0;
            o_mem_iriffa_data_ren     <=  0;
            state                     <=  PREPARE_MEM_INGRESS_PPFIFO;
          end
        end
        else begin
          //Finished
          o_mem_ingress_act           <=  0;
          state                       <=  FINISHED;
        end
        //Populate the Memory FIFO until we have read all the data from the ingress FIFO
      end
      WAIT_FOR_DMA_INGRESS: begin
        if (i_dma_iriffa_en) begin
          o_dma_iriffa_ack            <=  1;
          state                       <=  PREPARE_DMA_PPFIFO;
          r_fifo_size                 <=  i_dma_iriffa_len;
          r_fifo_pos                  <=  0;
        end
      end
      PREPARE_DMA_PPFIFO: begin
        //This only happens when we are writing data to dmaory
        //Grab a dmaory PPFIFO
        //Need to grab a PPFIFO for dmaory
        if ((i_dma_ingress_rdy > 0) && (o_dma_ingress_act == 0)) begin
          count                       <=  0;
          if (i_dma_ingress_rdy[0]) begin
            o_dma_ingress_act[0]      <=  1;
          end
          else begin
            o_dma_ingress_act[1]      <=  1;
          end
          state                       <=  WRITE_DMA_DATA;
        end
      end
      WRITE_DMA_DATA: begin
        if (r_fifo_pos < r_fifo_size) begin
          if (count < i_dma_ingress_size) begin
            o_dma_iriffa_data_ren     <=  1;
            if (o_dma_iriffa_data_ren && i_dma_iriffa_data_valid) begin
              count                   <=  count + 1;
              r_fifo_pos              <=  r_fifo_pos + 1;
              o_dma_ingress_data      <=  i_dma_iriffa_data;
              o_dma_ingress_stb       <=  1;
            end
            if (count >= (i_dma_ingress_size - 1)) begin
              o_dma_iriffa_data_ren   <=  0;
            end
          end
          else begin
            o_dma_ingress_act         <=  0;
            o_dma_iriffa_data_ren     <=  0;
            state                     <=  PREPARE_DMA_PPFIFO;
          end
        end
        else begin
          //Finished
          o_dma_ingress_act           <=  0;
          state                       <=  FINISHED;
        end
      end
      PREPARE_PERIPH_EGRESS: begin
        //Prepare the RIFFA Interface
        o_riffa_egress_sel            <=  `PERIPH_CHANNEL;
        o_per_eriffa_en               <=  1;
        o_per_eriffa_last             <=  1;
        o_per_eriffa_off              <=  0;
        o_per_eriffa_len              <=  RESP_HDR_COUNT + w_out_data_count - 1;
        o_per_eriffa_data_valid       <=  0;
        o_per_eriffa_data             <=  i_status;
        count                         <=  0;
        if (i_per_eriffa_ack) begin
          state                       <=  PREPARE_PERIPH_EGRESS_DATA;
        end
      end
      PREPARE_PERIPH_EGRESS_DATA: begin
        if (count < RESP_HDR_COUNT) begin
          o_per_eriffa_data           <= r_resp[count];
          o_per_eriffa_data_valid     <= 1;
          state                       <= SEND_PERIPH_EGRESS_DATA;
        end
        else if (count < o_per_eriffa_len) begin
          if (count == RESP_HDR_COUNT) begin //Special Case!
            //First DWORD Special Case (I know, FUGLY) but I need to fix the master to get this right
            o_per_eriffa_data         <= r_out_data;
            o_per_eriffa_data_valid   <= 1;
            state                     <= SEND_PERIPH_EGRESS_DATA;
          end
          else begin
            o_out_ready               <=  1;
            if (i_en) begin
              o_out_ready             <=  0;
              o_per_eriffa_data       <=  i_data;
              o_per_eriffa_data_valid <=  1;
              state                   <=  SEND_PERIPH_EGRESS_DATA;
            end
          end
        end
        else begin
          o_per_eriffa_en             <=  0;
          o_per_eriffa_last           <=  0;
          o_per_eriffa_off            <=  0;
          o_per_eriffa_len            <=  0;
          o_per_eriffa_data_valid     <=  0;
          state                       <=  FINISHED;
        end
      end
      SEND_PERIPH_EGRESS_DATA: begin
        if (i_per_eriffa_data_ren) begin
          o_per_eriffa_data_valid     <=  0;
          count                       <=  count + 1;
          state                       <=  PREPARE_PERIPH_EGRESS_DATA;
        end
      end
      SEND_MEM_EGRESS_DATA: begin
        //Prepare the RIFFA Interface
        o_riffa_egress_sel            <=  `MEMORY_CHANNEL;
        r_mem_egress_en               <=  1;
        r_mem_egress_length           <=  o_data_count;
        if (w_mem_egress_fin) begin
          r_mem_egress_en             <=  0;
          state                       <=  IDLE;
        end
      end
      SEND_DMA_EGRESS_DATA: begin
        //Prepare the RIFFA Interface
        o_riffa_egress_sel            <=  `DMA_CHANNEL;
        r_dma_egress_en               <=  1;
        r_dma_egress_length           <=  o_data_count;
        if (w_dma_egress_fin) begin
          r_dma_egress_en             <=  0;
          state                       <=  IDLE;
        end
      end
      FLUSH: begin
        if (count < r_fifo_size) begin
          o_per_iriffa_data_ren       <=  1;
          if (o_per_iriffa_data_ren && i_per_iriffa_data_valid) begin
            count                     <=  count + 1;
          end
        end
        else begin
          o_per_iriffa_data_ren       <=  0;
          state                       <=  FINISHED;
        end
      end
      FLUSH_OUTPUT: begin
        if (count < w_out_data_count) begin
          if (i_en) begin
            count                     <=  count + 1;
            o_out_ready               <=  0;
          end
          else begin
            o_out_ready               <=  1;
          end
        end
        else begin
          state                       <=  FINISHED;
        end
      end
      FINISHED: begin
        state                         <=  IDLE;
      end
      default: begin
      end
    endcase
  end
end

endmodule

