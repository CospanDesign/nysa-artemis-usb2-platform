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
 * Description: For those situations where you need to attach one PPFIFO with another
 *
 * Changes:
 */


module adapter_ppfifo_2_ppfifo #(
  parameter DATA_WIDTH              = 32
)(
  input                               clk,
  input                               rst,

  input                               i_read_ready,
  output  reg                         o_read_activate,
  input           [23:0]              i_read_size,
  input           [DATA_WIDTH - 1:0]  i_read_data,
  output  reg                         o_read_stb,

  input           [1:0]               i_write_ready,
  output  reg     [1:0]               o_write_activate,
  input           [23:0]              i_write_size,
  output  reg                         o_write_stb,
  output          [DATA_WIDTH - 1:0]  o_write_data

);
//registes/wires
reg [23:0]                            read_count;
reg [23:0]                            write_count;

assign  o_write_data    = i_read_data;

always @ (posedge clk) begin
  o_read_stb                      <=  0;
  o_write_stb                     <=  0;
  if (rst) begin
    o_write_activate              <=  0;
    o_read_activate               <=  0;
    write_count                   <=  0;
    read_count                    <=  0;
  end
  else begin
    if (i_read_ready && !o_read_activate) begin
      read_count                  <=  0;
      o_read_activate             <=  1;
    end
    if ((i_write_ready > 0) && (o_write_activate == 0)) begin
      write_count                   <=  0;
      if (i_write_ready[0]) begin
        o_write_activate[0]         <=  1;
      end
      else begin
        o_write_activate[1]         <=  1;
      end
    end

    //Both FIFOs are available
    if (o_read_activate && (o_write_activate > 0)) begin
      if ((write_count < i_write_size) && (read_count < i_read_size))begin
        o_write_stb                 <=  1;
        o_read_stb                  <=  1;
        write_count                 <=  write_count + 1;
        read_count                  <=  read_count + 1;
      end
      else begin
        if (write_count >= i_write_size) begin
          o_write_activate          <=  0;
        end
        if (read_count >= i_read_size) begin
          //Both FIFOs should be released, this way the output is never blocked on the input
          o_read_activate           <=  0;
          o_write_activate          <=  0;
        end
      end
    end
  end
end

endmodule
