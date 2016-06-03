// ----------------------------------------------------------------------
// Copyright (c) 2016, The Regents of the University of California All
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
//
//     * Neither the name of The Regents of the University of California
//       nor the names of its contributors may be used to endorse or
//       promote products derived from this software without specific
//       prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL REGENTS OF THE
// UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
// OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
// TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
// DAMAGE.
// ----------------------------------------------------------------------
//----------------------------------------------------------------------------
// Filename:			chnl_tester.v
// Version:				1.00.a
// Verilog Standard:	Verilog-2001
// Description:			Sample RIFFA channel user module. Designed to exercise
// 						the RIFFA TX and RX interfaces. Receives data on the
//						RX interface and saves the last value received. Sends
//						the same amount of data back on the TX interface. The
//						returned data starts with the last value received,
//						resets and increments to end with a value equal to the
//						number of (4 byte) words sent back on the TX interface.
// Author:				Matt Jacobsen
// History:				@mattj: Version 2.0
//-----------------------------------------------------------------------------
`timescale 1ns/1ns
module chnl_tester #(
	parameter C_PCI_DATA_WIDTH = 9'd32
)
(
	input                         clk,
	input                         rst,
	output                        chnl_rx_clk,
	input                         chnl_rx,
	output                        chnl_rx_ack,
	input                         chnl_rx_last,
	input [31:0]                  chnl_rx_len,
	input [30:0]                  chnl_rx_off,
	input [C_PCI_DATA_WIDTH-1:0]  chnl_rx_data,
	input                         chnl_rx_data_valid,
	output                        chnl_rx_data_ren,

	output                        chnl_tx_clk,
	output                        chnl_tx,
	input                         chnl_tx_ack,
	output                        chnl_tx_last,
	output [31:0]                 chnl_tx_len,
	output [30:0]                 chnl_tx_off,
	output [C_PCI_DATA_WIDTH-1:0] chnl_tx_data,
	output                        chnl_tx_data_valid,
	input                         chnl_tx_data_ren
);

//Local Paramters
localparam      IDLE          = 4'h0;
localparam      READ          = 4'h1;
localparam      PREPARE_WRITE = 4'h2;
localparam      WRITE         = 4'h3;
//Registers/Wires
//Submodules
//Asynchronous Logic

assign chnl_rx_clk        = clk;
assign chnl_rx_ack        = (state == READ);
assign chnl_rx_data_ren   = (state == READ);

assign chnl_tx_clk        = clk;
assign chnl_tx            = (state == WRITE);
assign chnl_tx_last       = 1;
assign chnl_tx_len        = r_length; // in words
assign chnl_tx_off        = 0;
assign chnl_tx_data       = r_data;
assign chnl_tx_data_valid = (state == WRITE);


//Synchronous Logic

reg [C_PCI_DATA_WIDTH-1:0]  r_data  ={C_PCI_DATA_WIDTH{1'b0}};
reg [31:0]                  r_length=0;
reg [31:0]                  count   =0;
reg [1:0]                   state   =IDLE;

always @(posedge clk or posedge rst) begin
	if (rst) begin
		r_length        <= #1 0;
		count           <= #1 0;
		r_data          <= #1 0;
		state           <= #1 IDLE;
	end
	else begin
		case (state)

		IDLE: begin // Wait for start of RX, save length
			if (chnl_rx) begin
				r_length    <= #1 chnl_rx_len;
				count       <= #1 0;
				state       <= #1 READ;
			end
		end
		READ: begin // Wait for last data in RX, save value
			if (chnl_rx_data_valid) begin
				r_data      <= #1 chnl_rx_data;
				count       <= #1 count + (C_PCI_DATA_WIDTH/32);
			end
			if (count >= r_length)
				state       <= #1 PREPARE_WRITE;
		end
		PREPARE_WRITE: begin // Prepare for TX
			count         <= #1 (C_PCI_DATA_WIDTH/32);
			state         <= #1 WRITE;
		end
		WRITE: begin // Start TX with save length and data value
			if (chnl_tx_data_ren & chnl_tx_data_valid) begin
				r_data      <= #1 {count + 4, count + 3, count + 2, count + 1};
				count       <= #1 count + (C_PCI_DATA_WIDTH/32);
				if (count >= r_length)
					state     <= #1 IDLE;
			end
		end
		endcase
	end
end

/*
wire [35:0] wControl0;
chipscope_icon_1 cs_icon(
	.CONTROL0(wControl0)
);

chipscope_ila_t8_512 a0(
	.clk(clk),
	.CONTROL(wControl0),
	.TRIG0({3'd0, (count >= 800), CHNL_RX, CHNL_RX_DATA_VALID, state}),
	.DATA({44IDLE,
			CHNL_TX_DATA_REN, // 1
			CHNL_TX_ACK, // 1
			CHNL_RX_DATA, // 64
			CHNL_RX_DATA_VALID, // 1
			CHNL_RX, // 1
			state}) // 2
);
*/

endmodule
