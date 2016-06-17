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
 *  Reads data from the host PCIE ingress interface and outputs it to a
 *  PPFIFO
 *
 *  This core is simple. It waits for an external controller to tell it when
 *  to write data to the Ping Pong FIFO.
 *
 *  How to control it:
 *    -The bram interface will never be blocked, the bram can always write data
 *    -When an external controller wants to send a block of 4096 dwords through
 *    the FIFO it sets the appropriate i_ppfifo_wr_en high:
 *      bit 0: 0x0000 - 0x0FFF
 *      bit 1: 0x1000 - 0x1FFF
 *    When the entire block has been completely written the 'o_ppfifo_wr_fin'
 *    goes high.
 *
 * Changes:
 *  5/2/2016: Initial Commit
 */

module buffer_builder #(
  parameter                           MEM_DEPTH   = 13,   //8K Buffer
  parameter                           DATA_WIDTH  = 32
)(
  input                               mem_clk,
  input                               rst,

  input           [1:0]               i_ppfifo_wr_en,     //When [0] is set write, lower half to PPFIFO
  output  reg                         o_ppfifo_wr_fin,    //When a PPFIFO is finished, set high

  //Memory Interface From
  input                               i_bram_we,
  input           [MEM_DEPTH  - 1: 0] i_bram_addr,
  input           [DATA_WIDTH - 1: 0] i_bram_din,

  //Ping Pong FIFO Interface
  input                               ppfifo_clk,

  input           [23:0]              i_data_count,

  input           [1:0]               i_write_ready,
  output  reg     [1:0]               o_write_activate,
  input           [23:0]              i_write_size,
  output  reg                         o_write_stb,
  output          [DATA_WIDTH - 1:0]  o_write_data
);
//local parameters

//States
localparam        IDLE        = 0;
localparam        WRITE_SETUP = 1;
localparam        WRITE       = 2;
localparam        FINISHED    = 3;

localparam        BASE0_OFFSET  = 0;
//localparam        BASE1_OFFSET  = ((2 ** (MEM_DEPTH) / 2));
localparam        BASE1_OFFSET  = ((2 ** MEM_DEPTH) / 2);

//registes/wires
reg   [3:0]                           state;
reg   [23:0]                          count;
reg   [MEM_DEPTH - 1: 0]              r_ppfifo_mem_addr;
reg   [MEM_DEPTH - 1: 0]              r_addr;


//submodules

//Write Data to a local buffer
dpb #(
  .DATA_WIDTH     (DATA_WIDTH           ),
  .ADDR_WIDTH     (MEM_DEPTH            )

) local_buffer (

  .clka           (mem_clk              ),
  .wea            (i_bram_we            ),
  .addra          (i_bram_addr          ),
  .douta          (                     ),
  .dina           (i_bram_din           ),

  .clkb           (ppfifo_clk           ),
  .web            (1'b0                 ),
  .addrb          (r_addr               ),
  .dinb           (32'h00000000         ),
  .doutb          (o_write_data         )
);


//asynchronous logic
//synchronous logic
always @ (posedge ppfifo_clk) begin
  o_write_stb                     <= 0;
  if (rst) begin
    o_write_activate              <= 0;
    o_ppfifo_wr_fin               <= 0;
    count                         <= 0;
    r_addr                        <= 0;
    state                         <= IDLE;
  end
  else begin
    case (state)
      IDLE: begin
        o_ppfifo_wr_fin           <= 0;
        o_write_activate          <= 0;
        r_addr                    <= 0;

        count                     <= 0;
        if (i_ppfifo_wr_en > 0) begin
          //Load the memory data into the PPFIFO
          if (i_ppfifo_wr_en[0]) begin
            r_addr                <= BASE0_OFFSET;
          end
          else begin
            r_addr                <= BASE1_OFFSET;
          end
          state                   <= WRITE_SETUP;
        end
      end
      WRITE_SETUP: begin
        if ((i_write_ready > 0) && (o_write_activate == 0)) begin
          if (i_write_ready[0]) begin
            o_write_activate[0]   <= 1;
          end
          else begin
            o_write_activate[1]   <= 1;
          end
          state                   <= WRITE;
        end
      end
      WRITE: begin
        //if (count < i_write_size) begin
        if (count < i_data_count) begin
          r_addr                  <= r_addr + 1;
          o_write_stb             <= 1;
          count                   <= count + 1;
        end
        else begin
          o_write_activate        <= 0;
          state                   <= FINISHED;
        end
      end
      FINISHED: begin
        o_ppfifo_wr_fin           <= 1;
        if (i_ppfifo_wr_en == 0) begin
          o_ppfifo_wr_fin         <= 0;
          state                   <= IDLE;
        end
      end
      default: begin
        //Shouldn't get here
        state                     <= IDLE;
      end
    endcase
  end
end

endmodule
