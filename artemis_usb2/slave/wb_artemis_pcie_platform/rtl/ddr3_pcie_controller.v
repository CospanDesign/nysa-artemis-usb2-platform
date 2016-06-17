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

`timescale 1 ns/1 ps


module ddr3_pcie_controller (

input                       clk,
input                       rst,

//Memory Controller Interface
input         [31:0]        data_size,
input         [27:0]        write_address,
input                       write_en, //set high to initiate a write transaction
                                      //this will not finish until everything in the PPFIFO is empty
input         [27:0]        read_address,
input                       read_en,  //set high to start populating the read FIFO, set low to end immediately
output  reg                 finished,

//PPFIFO Interface
input                       if_write_strobe,
input         [31:0]        if_write_data,
output        [1:0]         if_write_ready,
input         [1:0]         if_write_activate,
output        [23:0]        if_write_fifo_size,
output                      if_starved,

input                       of_read_strobe,
output                      of_read_ready,
input                       of_read_activate,
output        [23:0]        of_read_size,
output        [31:0]        of_read_data,
output                      of_read_inactive,

//Local Registers/Wires
output  reg                 cmd_en,       //Command is strobed into controller
output  reg   [2:0]         cmd_instr,    //Instruction
output  reg   [5:0]         cmd_bl,       //Burst Length
output  reg   [27:0]        cmd_word_addr,//Word Address
input                       cmd_empty,    //Command FIFO empty
input                       cmd_full,     //Command FIFO full

output  reg                 wr_en,        //Write Data strobe
output  reg   [3:0]         wr_mask,      //Write Strobe Mask (Not used, always set to 0)
output        [31:0]        wr_data,      //Data to write into memory
input                       wr_full,      //Write FIFO is full
input                       wr_empty,     //Write FIFO is empty
input         [6:0]         wr_count,     //Number of words in the write FIFO, this is slow to respond
input                       wr_underrun,  //There isn't enough data to fullfill the memory transaction
input                       wr_error,     //FIFO pointers are unsynchronized a reset is the only way to recover

output                      rd_en,        //Enable a read from memory FIFO
input         [31:0]        rd_data,      //data read from FIFO
input                       rd_full,      //FIFO is full
input                       rd_empty,     //FIFO is empty
input         [6:0]         rd_count,     //Number of elements inside the FIFO (This is slow to respond, so don't use it as a clock to clock estimate of how much data is available
input                       rd_overflow,  //the FIFO is overflowed and data is lost
input                       rd_error      //FIFO pointers are out of sync and a reset is required
);

//Local Parameters
localparam            CMD_WRITE     = 3'b000;
localparam            CMD_READ      = 3'b001;
localparam            CMD_WRITE_PC  = 3'b010;
localparam            CMD_READ_PC   = 3'b011;
localparam            CMD_REFRESH   = 3'b100;


localparam            IDLE          = 4'h0;
localparam            WRITE_READY   = 4'h1;
localparam            WRITE_FLUSH   = 4'h2;
localparam            WRITE_DATA    = 4'h3;
localparam            WRITE_COMMAND = 4'h4;
localparam            READ_READY    = 4'h5;
localparam            READ_COMMAND  = 4'h6;
localparam            READ_DATA     = 4'h7;
localparam            FINISHED      = 4'h8;

//Registers/Wires

//Write path
reg         [3:0]   state;
reg         [27:0]  local_address;
reg         [31:0]  count;

wire                if_fifo_idle;

reg                 if_read_strobe;
wire                if_read_ready;
reg                 if_read_activate;
wire        [23:0]  if_read_size;
wire        [31:0]  if_read_data;
wire                if_inactive;

reg         [23:0]  if_read_count;

//Read Path
wire                of_starved;
reg                 of_fifo_reset = 0;
//Read Signals
wire        [1:0]   of_write_ready;
reg         [1:0]   of_write_activate;
wire        [23:0]  of_write_size;
wire                of_write_strobe;
reg         [23:0]  of_write_count;
reg                 read_request;
reg                 read_request_count;


reg         [31:0]  data;

//Submodules
//to_ddr3_fifo
ppfifo#(
  .DATA_WIDTH             (32                                        ),
  .ADDRESS_WIDTH          (6                                         )
)user_2_mem(
  .reset                  (rst                                       ),

  //Write
  .write_clock            (clk                                       ),
  .write_ready            (if_write_ready                            ),
  .write_activate         (if_write_activate                         ),
  .write_fifo_size        (if_write_fifo_size                        ),
  .write_strobe           (if_write_strobe                           ),
  .write_data             (if_write_data                             ),

  .starved                (if_starved                                ),

  //Read
  .read_clock             (clk                                       ),
  .read_strobe            (if_read_strobe                            ),
  .read_ready             (if_read_ready                             ),
  .read_activate          (if_read_activate                          ),
  .read_count             (if_read_size                              ),
  .read_data              (if_read_data                              ),

  .inactive               (if_inactive                               )
);

ppfifo#(
  .DATA_WIDTH             (32                                         ),
  .ADDRESS_WIDTH          (6                                          )
)mem_2_user(
  .reset                  (rst || of_fifo_reset                       ),
  //.reset                  (rst || !read_en                            ),

  //Write
  .write_clock            (clk                                        ),
  .write_ready            (of_write_ready                             ),
  .write_activate         (of_write_activate                          ),
  .write_fifo_size        (of_write_size                              ),
  .write_strobe           (of_write_strobe                            ),
  .write_data             (rd_data                                    ),
  //.write_data             (32'h01234567                               ),

  .starved                (of_starved                                 ),

  //Read
  .read_clock             (clk                                        ),
  .read_strobe            (of_read_strobe                             ),
  .read_ready             (of_read_ready                              ),
  .read_activate          (of_read_activate                           ),
  .read_count             (of_read_size                               ),
  .read_data              (of_read_data                               ),

  .inactive               (of_read_inactive                           )

);
//Asynchronous Logic
assign    rd_en           = (read_request & !rd_empty);
assign    of_write_strobe = rd_en;
assign    wr_data         = if_read_data;

//Synchronous Logic
always @ (posedge clk) begin
  if (rst) begin

    state             <=  IDLE;

    cmd_en            <=  0;
    cmd_instr         <=  0;
    cmd_bl            <=  0;
    cmd_word_addr     <=  0;

    wr_en             <=  0;  //Strobe data into the write FIFO
    //wr_data           <=  0;  //Data to be sent into the wirte FIFO
    wr_mask           <=  0;

    //rd_en             <=  0;  //Read Strobe
    read_request      <=  0;
    read_request_count<=  0;

    if_read_strobe    <=  0;
    if_read_activate  <=  0;
    if_read_count     <=  0;


    of_fifo_reset     <=  0;
    of_write_activate <=  0;

    of_write_count    <=  0;
    //data              <=  0;
    count             <=  0;
    local_address     <=  0;
    finished          <=  0;
  end
  else begin
    //Strobes
    cmd_en            <=  0;
    wr_en             <=  0;
    //rd_en             <=  0;
    read_request      <=  0;

    if_read_strobe    <=  0;

    of_fifo_reset     <=  0;


    //Get an incomming FIFO when available
    if (if_read_ready && !if_read_activate) begin
      if_read_count           <=  0;
      if_read_activate        <=  1;
    end
    //Get an outgoing FIFO when available
    if ((state == READ_READY) && (of_write_ready > 0) && (of_write_activate == 0)) begin
      of_write_count          <=  0;
      if (of_write_ready[0]) begin
        of_write_activate[0]  <=  1;
      end
      else begin
        of_write_activate[1]  <=  1;
      end
    end


    case (state)
      IDLE: begin
        count                 <=  0;
        //finished              <=  1;
        if (write_en) begin
          finished            <=  0;
          state               <=  WRITE_READY;
          local_address       <=  write_address;
        end
        else if (read_en) begin
          finished            <=  0;
          state               <=  READ_READY;
          local_address       <=  read_address;
        end
      end
      WRITE_READY: begin
        //Wait for a FIFO to become ready
        if (if_read_activate) begin
          if (count < data_size)begin
            state               <=  WRITE_DATA;
          end
          else begin
            state               <=  WRITE_FLUSH;
            finished            <=  1;
          end
        end
        else if ((count >= data_size) & if_inactive) begin
          //XXX:  There might be an error where data can possible get through when inactive
          //      For example writing one piece of data as the last piece
          //state                 <=  IDLE;
          state                 <=  FINISHED;
          finished              <=  1;
        end
        else if (!write_en) begin
          //state                 <=  IDLE;
          state                 <=  FINISHED;
        end
      end
      WRITE_FLUSH: begin
        if (if_read_activate) begin
          if (if_read_count < if_read_size) begin
            if_read_strobe      <=  1;
            if_read_count       <=  if_read_count + 1;
          end
          else begin
            if_read_activate    <=  0;
          end
        end
        else begin
          if_read_activate      <=  0;
          state                 <=  WRITE_READY;
        end
      end
      WRITE_DATA: begin
        //Since the maximum amount of data can only be 64 we can only fill up the write FIFO
        //After we sent out all the data o to write command to issue a command to take care of this
        if ((if_read_count       < if_read_size) && (count < data_size))begin
          //if (!wr_full) begin
          if (wr_count < 6'h3F) begin
            //data                <=  if_read_data;
            //wr_data             <=  if_read_data;
            wr_en               <=  1;
            if_read_count       <=  if_read_count + 24'h1;
            if_read_strobe      <=  1;
            count               <=  count + 1;
          end
          else begin
            $display ("FIFO Full, attempting to write: %h", if_read_data);
          end
        end
        else begin
          state                 <=  WRITE_COMMAND;
        end
      end
      WRITE_COMMAND: begin
        if (!cmd_full) begin
          cmd_instr             <=  CMD_WRITE_PC;
          cmd_bl                <=  if_read_count - 24'h1;
          cmd_word_addr         <=  local_address;
          cmd_en                <=  1;

          if (if_read_count >= if_read_size) begin
            if_read_activate    <=  0;
          end
          state                 <=  WRITE_READY;
          local_address         <=  local_address + if_read_count;
        end
      end
      READ_READY: begin
        if (read_en) begin
          if (of_write_activate > 0) begin
            state               <=  READ_COMMAND;
          end
        end
        else begin
          state                 <=  IDLE;
          of_fifo_reset         <=  1;
        end
      end
      READ_COMMAND: begin
        //Send the read command
        if(!cmd_full) begin
            cmd_instr           <=  CMD_READ_PC;
            cmd_bl              <=  of_write_size - 24'h1;
            cmd_word_addr       <=  local_address;
            cmd_en              <=  1;

            local_address       <=  local_address + of_write_size;
            state               <=  READ_DATA;
        end
      end
      READ_DATA: begin
        if ((of_write_activate > 0) && (of_write_count < of_write_size)) begin
          //if (!rd_empty) begin
          read_request          <=  1;
          if (rd_en) begin
          //Srobe the data into the PPFIFO
            //rd_en               <=  1;
            of_write_count      <=  of_write_count + 24'h1;
            count               <=  count + 1;
          end
        end
        else begin
          if (count < data_size) begin
            state                 <=  READ_READY;
            if ((of_write_activate > 0) && (of_write_count > 0) && (!of_write_strobe)) begin
              of_write_activate   <=  0;
            end
          end
          else begin
            of_write_activate   <=  0;
            state               <= FINISHED;
          end
        end
      end
      FINISHED: begin
        finished                <=  1;
        if (!read_en && !write_en) begin
          finished              <=  0;
          state                 <=  IDLE;
          of_fifo_reset         <=  1;
        end
      end
      default: begin
        //XXX: Error Message
        state                   <=  0;
      end
    endcase

  end
end

endmodule
