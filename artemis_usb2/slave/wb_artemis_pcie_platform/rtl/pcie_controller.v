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
 * Description: Controls PCIE Bus by translating incomming commands
 *  from the AXI stream interface and then issuing:
 *  system:
 *    Commands
 *    Data Routing
 *    Host Requests
 *
 * Changes:
 *  3/23/2016: Initial Version
 */

`include "pcie_defines.v"
`include "nysa_pcie_defines.v"

module pcie_controller (
  input                     clk,
  input                     rst

  input                     i_core_ready,
  input       [6:0]         i_bar_hit,

  input       [31:0]        i_control_addr_base,
  //System Controller

  //Parsed out control data
  output  reg [31:0]        o_write_a_addr,
  output  reg [31:0]        o_write_b_addr,
  output  reg [31:0]        o_read_a_addr,
  output  reg [31:0]        o_read_b_addr,
  output  reg [31:0]        o_status_addr,
  output  reg [31:0]        o_buffer_size,
  output  reg [31:0]        o_ping_value,
  output  reg [31:0]        o_update_buf_status,

  output  reg               o_reg_write_stb,

  //Control Interface
  output  reg [31:0]        o_dword_size,

  //AXI Stream Host 2 Device
  input                     i_axi_ingress_clk,
  output  reg               o_axi_ingress_ready,
  input       [31:0]        i_axi_ingress_data,
  input       [3:0]         i_axi_ingress_keep,
  input                     i_axi_ingress_last,
  input                     i_axi_ingress_valid,

  //AXI Stream Device 2 Host
  output                    o_axi_egress_clk,
  input                     i_axi_egress_ready,
  output  reg [31:0]        o_axi_egress_data,
  output      [3:0]         o_axi_egress_keep,
  output  reg               o_axi_egress_last,
  output  reg               o_axi_egress_valid,

  //PPFIFO Host 2 Device FIFO
  input       [1:0]         i_egress_ready,
  output reg  [1:0]         o_egress_activate,
  input       [23:0]        i_egress_size,
  output reg                o_egress_stb,
  output reg  [31:0]        o_egress_data,

  //PPFIFO Device 2 Host FIFO
  output reg                o_ingress_stb,
  input                     i_ingress_ready,
  output reg                o_ingress_activate,
  input       [23:0]        i_ingress_count,
  input       [31:0]        i_ingress_data
);

//local parameters

//Control State Machine
localparam  IDLE                    = 4'h0;
localparam  EXECUTE_WRITE_COMMAND   = 4'h1;
localparam  EXECUTE_READ_COMMAND    = 4'h2;
localparam  EXECUTE_READ_CONFIG     = 4'h3;


//Write State Machine
//localparam  IDLE                    = 4'h0;
localparam  READY                   = 4'h1;
localparam  READ_HDR                = 4'h2;
localparam  WRITE_REG               = 4'h3;
localparam  WRITE_CMD               = 4'h4;
localparam  READ_CMPLT              = 4'h5;
localparam  FLUSH                   = 4'h6;
localparam  FINISH                  = 4'hF;

//Read State Machine
//localparam  IDLE                    = 4'h0;
localparam  SEND_WR_HDR             = 4'h1;
localparam  SEND_WR_DATA            = 4'h2;





//Commands
localparam  CMD_MEM_READ            = 8'h00;
localparam  CMD_MEM_READ_LOCK       = 8'h01;
localparam  CMD_MEM_WRITE           = 8'h02;
localparam  CMD_IO_READ             = 8'h03;
localparam  CMD_IO_WRITE            = 8'h04;
localparam  CMD_CONFIG_READD0       = 8'h05;
localparam  CMD_CONFIG_WRITE0       = 8'h06;
localparam  CMD_CONFIG_READ1        = 8'h07;
localparam  CMD_CONFIG_WRITE1       = 8'h08;
localparam  CMD_TCFGRD              = 8'h09;
localparam  CMD_TCFGWR              = 8'h0A;
localparam  CMD_MESSAGE             = 8'h0B;
localparam  CMD_MESSAGE_DATA        = 8'h0C;
localparam  CMD_COMPLETE            = 8'h0D;
localparam  CMD_COMPLETE_DATA       = 8'h0E;
localparam  CMD_COMPLETE_LOCK       = 8'h0F;
localparam  CMD_COMPLETE_DATA_LOCK  = 8'h10;
localparam  CMD_FETCH_ADD           = 8'h11;
localparam  CMD_SWAP                = 8'h12;
localparam  CMD_COMPARE_AND_SWAP    = 8'h13;
localparam  CMD_LPRF                = 8'h14;
localparam  CMD_EPRF                = 8'h15;
localparam  CMD_UNKNOWN             = 8'h16;


//Write Transaction Type
localparam  WR_TYPE_NONE            = 2'h0;
localparam  WR_TYPE_CFG             = 2'h1;
localparam  WR_TYPE_DATA            = 2'h2;
localparam  WR_TYPE_DATA_REQ        = 2'h3;

//registes/wires
reg   [3:0]   state;
reg   [3:0]   rd_state;
reg   [3:0]   wr_state;

reg   [3:0]   r_rd_hdr_index;

reg   [31:0]  r_rd_hdr [0:3];
wire  [9:0]   w_rcv_pkt_size;
wire  [9:0]   w_rcv_max_size;

reg   [2:0]   r_rd_hdr_size;
reg   [7:0]   r_rd_hdr_cmd;

reg           r_cmd_enable_stb;
reg           r_rcv_cmplt_stb;

wire  [3:0]   w_reg_addr;
wire          w_ingress_path_rdy;

reg   [1:0]   r_buf_status;
reg   [1:0]   r_update_buf_status;
reg           r_reg_write_stb;

reg           r_cmd_write;
reg           r_cmd_read;
reg           r_flag_fifo;
reg           r_cmd_ping;
reg           r_cmd_read_cfg;
reg           r_cmd_unknown;

reg   [31:0]  r_dword_count;
reg   [31:0]  r_buffer_pos;
reg           r_buffer_sel;

//Write Registers
wire          w_wr_busy;

reg   [1:0]   r_send_type;
wire          w_wr_sm_en;
reg           r_wr_cfg_en;

reg           r_wr_hdr_type;

reg           r_wr_finished;
reg   [3:0]   r_wr_hdr_index;
wire  [31:0]  w_wr_hdr [0:3];
wire  [13:0]  w_wr_hdr_flags;

wire  [31:0]  w_wr_buf_addr[1:0];
wire  [31:0]  w_rd_buf_addr[1:0];

wire  [31:0]  w_wr_buf_avail;
wire  [31:0]  w_rd_buf_avail;

reg   [31:0]  r_wr_pkt_addr;


wire  [1:0]   w_traffic_class;
wire          w_id_based;
wire  [1:0]   w_ordering;
wire          w_no_snoop;
wire          w_digest;
wire          w_poisoned;
wire          w_hint;



wire  [31:0]  w_config_regs[0:`CONFIG_REGISTER_COUNT];


assign  w_traffic_class = 2'b00;
assign  w_id_based      = 1'b0; //use address no tID
assign  w_ordering      = 1'b0; // Default Ordering
assign  w_no_snoop      = 1'b1;
assign  w_digest        = 1'b0; // No digest at the end of packet
assign  w_poisoned      = 1'b0;
assign  w_hint_avail    = 1'b0;
assign  w_atomic        = 2'b00;
assign  w_process_hint  = 2'b00;

assign  w_wr_hdr_flags  = { 1'b0,
                            w_traffic_class,
                            1'b0,
                            w_id_based,
                            1'b0,
                            w_hint_avail,
                            w_digest,
                            w_poisoned
                            w_ordering,
                            w_no_snoop};


assign  w_config_regs[`STATUS_BUF_ADDR]   = o_status;
assign  w_config_regs[`BUFFER_READY]      = {29'h0, r_buf_status};
assign  w_config_regs[`WRITE_BUF_A_ADDR]  = o_write_a_addr;
assign  w_config_regs[`WRITE_BUF_B_ADDR]  = o_write_b_addr;
assign  w_config_regs[`READ_BUF_A_ADDR]   = o_read_a_addr;
assign  w_config_regs[`READ_BUF_B_ADDR]   = o_read_b_addr;
assign  w_config_regs[`BUFFER_SIZE]       = o_buffer_size;
assign  w_config_regs[`PING_VALUE]        = o_ping_value;


assign  w_wr_buf_addr[0] = o_write_a_addr;
assign  w_wr_buf_addr[1] = o_write_b_addr;

assign  w_rd_buf_addr[0] = o_read_a_addr;
assign  w_rd_buf_addr[1] = o_read_b_addr;

assign  w_wr_buf_avail   = w_wr_buf_addr[r_buf_sel] - r_buffer_pos;
assign  w_rd_buf_avail   = w_rd_buf_addr[r_buf_sel] - r_buffer_pos;



//submodules
//asynchronous logic

//Get Header Size
always @ (*) begin
  case (r_rd_hdr[0][`PCIE_FMT_RANGE])
    `PCIE_FMT_3DW_NO_DATA:  r_rd_hdr_size = 3;
    `PCIE_FMT_4DW_NO_DATA:  r_rd_hdr_size = 4;
    `PCIE_FMT_3DW_DATA:     r_rd_hdr_size = 3;
    `PCIE_FMT_4DW_DATA:     r_rd_hdr_size = 4;
    default:                r_rd_hdr_size = 0;
  endcase
end

always @ (*) begin
  casex (r_rd_hdr[0][`PCIE_TYPE_RANGE])
    `PCIE_MRD:              r_rd_hdr_cmd = CMD_MEM_READ;
    `PCIE_MRDLK:            r_rd_hdr_cmd = CMD_MEM_READ_LOCK;
    `PCIE_MWR:              r_rd_hdr_cmd = CMD_MEM_WRITE;
    `PCIE_IORD:             r_rd_hdr_cmd = CMD_IO_READ;
    `PCIE_IOWR:             r_rd_hdr_cmd = CMD_IO_WRITE;
    `PCIE_CFGRD0:           r_rd_hdr_cmd = CMD_CONFIG_READD0;
    `PCIE_CFGWR0:           r_rd_hdr_cmd = CMD_CONFIG_WRITE0;
    `PCIE_CFGRD1:           r_rd_hdr_cmd = CMD_CONFIG_READ1;
    `PCIE_CFGWR1:           r_rd_hdr_cmd = CMD_CONFIG_WRITE1;
    `PCIE_TCFGRD:           r_rd_hdr_cmd = CMD_TCFGRD;
    `PCIE_TCFGWR:           r_rd_hdr_cmd = CMD_TCFGWR;
    `PCIE_MSG:              r_rd_hdr_cmd = CMD_MESSAGE;
    `PCIE_MSG_D:            r_rd_hdr_cmd = CMD_MESSAGE_DATA;
    `PCIE_CPL:              r_rd_hdr_cmd = CMD_COMPLETE;
    `PCIE_CPL_D:            r_rd_hdr_cmd = CMD_COMPLETE_DATA;
    `PCIE_CPLLK:            r_rd_hdr_cmd = CMD_COMPLETE_LOCK
    `PCIE_CPLDLK:           r_rd_hdr_cmd = CMD_COMPLETE_DATA_LOCK;
    `PCIE_FETCH_ADD:        r_rd_hdr_cmd = CMD_FETCH_ADD;
    `PCIE_SWAP:             r_rd_hdr_cmd = CMD_SWAP;
    `PCIE_CAS:              r_rd_hdr_cmd = CMD_COMPARE_AND_SWAP;
    `PCIE_LPRF:             r_rd_hdr_cmd = CMD_LPRF;
    `PCIE_EPRF:             r_rd_hdr_cmd = CMD_EPRF;
    default:
  endcase
end

//Compare between space in buffer, number of words left to read/write and egress/ingress write size
//XXX: CAVIAT! If not the last packet the host side buffer should be a multiple of egress/ingress side

assign  w_rcv_pkt_size                    = r_rd_hdr[0][`PCIE_DWORD_PKT_CNT_RANGE];
assign  w_rcv_max_size                    = (w_rcv_pkt_size > i_egress_size) ? i_egress_size: w_rcv_pkt_size;


assign  w_reg_addr                        = (i_control_addr_base > 0) ? (r_rd_hdr[2] - i_control_addr_base): 32'h00;
assign  w_cmd_en                          = (w_reg_addr > CMD_OFFSET);

assign  w_wr_busy                         = (wr_state != ILDE);

assign  o_status[`STATUS_UNUSED]          =  0;
assign  o_status[`STATUS_BIT_BUSY]        =  !w_wr_sm_en;
assign  o_status[`STATUS_BIT_WRITING]     =  r_cmd_write;
assign  o_status[`STATUS_BIT_READING]     =  r_cmd_read;
assign  o_status[`STATUS_BIT_FIFO]        =  r_flag_fifo;
assign  o_status[`STATUS_BIT_PING]        =  r_cmd_ping;
assign  o_status[`STATUS_BIT_READ_CFG]    =  r_cmd_read_cfg;
assign  o_status[`STATUS_BIT_UNKNOWN_CMD] =  r_cmd_unknown;


//If we are waiting for a command then we are ready or we need to wait for the input FIFO to be ready

//A register write transaction
assign  w_command_path_rdy                = i_bar_hit[0];

//Reasons to start a read transaction
assign  w_ingress_path_rdy                = w_command_path_rdy || (i_egress_ready > 0);
assign  w_wr_sm_en                        = (r_send_type != WR_TYPE_NONE);


assign  o_axi_egress_keep                 =  4'hF;

assign  w_wr_hdr[0]                       =  {r_wr_hdr_type, w_wr_hdr_flags, r_wr_pkt_dwrd_cnt[9:0]};
assign  w_wr_hdr[1]                       =  {24'h0, 8'hFF};
assign  w_wr_hdr[2]                       =  {w_wr_buf_addr[r_buf_sel][31:2], w_process_hint};
assign  w_wr_hdr[3]                       =  0;



//Synchronous logic

//Main State Machine
always @ (posedge clk) begin
  if (rst) begin
    state                     <=  IDLE;

    r_cmd_write               <=  0;
    r_cmd_read                <=  0;
    r_flag_fifo               <=  0;
    r_cmd_ping                <=  0;
    r_cmd_unknown             <=  0;

    r_dword_count             <=  0;
    o_dev_sel                 <= `SELECT_CONTROL;
    r_buf_status              <=  0;
    r_buffer_pos              <=  0;
    r_buffer_sel              <=  0;

    //Write Interface
    r_wr_pkt_dwrd_cnt         <=  0;
    r_wr_pkt_addr             <=  0;

    r_send_type               <=  WR_TYPE_NONE;
  end
  else begin
    case (state)
      IDLE: begin
        if (r_cmd_enable_stb) begin
          r_dword_count                       <=  0;
          r_buffer_pos                        <=  0;
          r_buffer_sel                        <=  0;
          case (w_reg_addr)
            `COMMAND_RESET: begin
              o_dev_sel                       <=  `SELECT_CONTROL;
              r_send_type                     <=  WR_TYPE_NONE;
            end
            `PERIPHERAL_WRITE: begin
              o_dev_sel                       <=  `SELECT_PERIPH;
              r_cmd_write                     <=  1;
              state                           <=  EXECUTE_WRITE_COMMAND;
            end
            `PERIPHERAL_WRITE_FIFO: begin
              o_dev_sel                       <=  `SELECT_PERIPH;
              r_cmd_write                     <=  1;
              r_flag_fifo                     <=  1;
              state                           <=  EXECUTE_WRITE_COMMAND;
            end
            `PERIPHERAL_READ: begin
              r_cmd_read                      <=  1;
              o_dev_sel                       <=  `SELECT_PERIPH;
              state                           <=  EXECUTE_READ_COMMAND;
            end
            `PERIPHERAL_READ_FIFO: begin
              o_dev_sel                       <=  `SELECT_PERIPH;
              r_cmd_read                      <=  1;
              r_flag_fifo                     <=  1;
              state                           <=  EXECUTE_READ_COMMAND;
            end
            `MEMORY_WRITE: begin
              o_dev_sel                       <=  `SELECT_MEM;
              r_cmd_write                     <=  1;
              state                           <=  EXECUTE_WRITE_COMMAND;
            end
            `MEMORY_READ: begin
              o_dev_sel                       <=  `SELECT_MEM;
              r_cmd_read                      <=  1;
              state                           <=  EXECUTE_READ_COMMAND;
            end
            `DMA_WRITE: begin
              o_dev_sel                       <=  `SELECT_DMA;
              r_cmd_write                     <=  1;
              state                           <=  EXECUTE_WRITE_COMMAND;
            end
            `DMA_READ: begin
              o_dev_sel                       <=  `SELECT_DMA;
              r_cmd_read                      <=  1;
              state                           <=  EXECUTE_READ_COMMAND;
            end
            `PING: begin
              o_dev_sel                       <=  `SELECT_CONTROL;
              r_cmd_ping                      <=  1;
              state                           <=  EXECUTE_READ_CONFIG;
              o_ping_value                    <=  o_dword_size;
            end
            `READ_CONFIG: begin
              o_dev_sel                       <=  `SELECT_CONTROL;
              r_cmd_read_cfg                  <=  1;
              state                           <=  EXECUTE_READ_CONFIG;
            end
            default: begin
              o_dev_sel                       <=  `SELECT_CONTROL;
              r_cmd_unknown                   <=  1;
              state                           <=  EXECUTE_READ_CONFIG;
            end
          endcase
        end
      end
      EXECUTE_WRITE_COMMAND: begin
        r_send_type                           <=  WR_TYPE_NONE;
//XXX: This could be done faster by sending multiple requests to the host
        if (r_dword_count >= o_dword_size) begin
          //Check if we read all the data from the host
          state                               <=  IDLE;
        end
        else if (r_buffer_pos >= o_buffer_size) begin
          //Check if the next buffer is ready
          if (!w_wr_busy) begin
            //Tell the host that the current buffer is not ready
            r_buf_status[r_buf_sel]           <=  0;
            state                             <=  EMC_INT_BUF_STS;
            r_send_type                       <=  WR_TYPE_CFG;
          end
        end
        else if (o_egress_ready) begin
          //Check if the next buffer is ready
          if (!w_wr_busy) begin
            //based on the commands we need are tasked with we need to execute reads or writes
            //Set the read address
            r_wr_pkt_addr                     <=  w_wr_buf_addr[r_buf_sel] + r_buffer_pos;
            //set the read count
            r_wr_pkt_dwrd_cnt                 <=  w_rcv_max_size;
            //Enable the transmit state machine
            r_send_type                       <=  WR_TYPE_DATA;
            //Wait for data from the host
            state                             <=  EWC_WAIT_FOR_DATA;
          end
        end
      end
      EWC_WAIT_FOR_DATA: begin
        if (rcv_cmplt_stb) begin
          r_dword_count                       <=  r_dword_count + w_rcv_pkt_size;
          r_buffer_pos                        <=  r_buffer_pos + w_rcv_pkt_size;
          state                               <=  EXECUTE_WRITE_COMMAND;
        end
      end
      EMC_INT_BUF_STS: begin
        //We sent a notification to the host saying (one or both of the buffers are not available)
        //Check if the other buffer is ready
        if (r_buf_status[!r_buf_sel]) begin
          // The other buffer is ready go, to that buffer
          r_buf_sel                           <=  ~r_buf_sel;
          state                               <=  EXECUTE_WRITE_COMMAND;
        end
      end

      EXECUTE_READ_COMMAND: begin
        r_send_type                           <=  WR_TYPE_NONE;
      end
      EXECUTE_READ_CONFIG: begin
      end
      //Handle 'Write' Transaction
        //Send a read request for some or part of the data
        //Wait for the host
        //If the total amount of data is sent send the final status interrupt
        //If only part of the data is sent but I used up all of the buffer send a status interrupt saying the buffer
          //is finished. Check the buffer status to determine if there is a buffer available.
          //If both buffers are full wait until the user has finished reading the first buffer before sending the second
          //this will help the driver determine which device towrite from first.

      //Handle a 'Read' Transaction
        //Wait for the associate incomming FIFO to become ready
        //When it's ready, tell the transmit state machine to start transmitting the data

      //Ping: Transmit a write request to the memory
      //
      default: begin
      end
    endcase

    if (r_reg_write_stb) begin
      r_buf_status                            <=  r_update_buf_status;
    end


    if (r_wr_finished) begin
      r_send_type                             <=  WR_TYPE_NONE;
    end
  end
end


//Read State Machine
always @ (posedge clk) begin
  r_cmd_enable_stb            <=  0;
  r_reg_write_stb             <=  0;
  r_rcv_cmplt_stb             <=  0;

  o_egress_stb                <=  0;

  if (rst) begin
    rd_state                  <=  IDLE;
    o_axi_ingress_ready       <=  1'b0;
    r_rd_hdr_index               <=  0;
    o_dword_size              <=  0;
    r_egress_data_count       <=  0;

    //Registers
    o_write_a_addr            <=  0;
    o_write_b_addr            <=  0;
    o_read_a_addr             <=  0;
    o_read_b_addr             <=  0;
    o_status_addr             <=  0;
    r_update_buf_status       <=  0;

    //FIFO Registers
    o_egress_activate         <=  0;
    o_egress_data             <=  0;
  end
  else begin
    //Get an available FIFO
    if ((i_egress_ready > 0) && (o_egress_activate == 0)) begin
      r_egress_data_count     <=  0;
      if (i_egress_ready[0]) begin
        o_egress_activate[0]  <=  1;
      end
      else begin
        o_egress_activate[1]  <=  1;
      end
    end

    case (rd_state)
      IDLE: begin
        if (w_ingress_path_rdy) begin
          rd_state            <=  READY;
        end
      end
      READY: begin
        o_axi_ingress_ready   <=  1;
        r_rd_hdr_index           <=  0;
        if (i_axi_ingress_valid) begin
          r_rd_hdr[r_rd_hdr_index]  <=  i_axi_ingress_data;
          r_rd_hdr_index         <=  r_rd_hdr_index + 1;
          rd_state            <=  READ_HDR;
        end
      end
      READ_HDR: begin
        r_rd_hdr[r_rd_hdr_index]    <=  i_axi_ingress_data;
        r_rd_hdr_index           <=  r_rd_hdr_index + 1;
        if ((r_rd_hdr_index + 1) >= w_hdr_size) begin
          //We read everything within the packet
          case (r_rd_hdr_cmd) begin
            CMD_MEM_WRITE: begin
              //Absorb the next 'length' of data and put it address

              if (w_cmd_en) begin
                rd_state      <=  WRITE_CMD;
              end
              else begin
                rd_state      <=  WRITE_REG;
              end
            end
            CMD_COMPLETE_DATA: begin
              rd_state        <=  READ_CMPLT;
            end
            default: begin
              rd_state        <=  FLUSH;
            end
          endcase
        end
      end
      WRITE_REG: begin
        case (w_reg_addr)
          `STATUS_BUS_ADDR: begin
            o_status_addr             <=  i_axi_ingress_data;
          end
          `BUFFER_READY: begin
            r_update_buf_status       <=  i_axi_ingress_data[`BUFFER_READY_RANGE];
          end
          `WRITE_BUF_A_ADDR: begin
            o_write_a_addr            <=  i_axi_ingress_data;
          end
          `WRITE_BUF_B_ADDR: begin
            o_write_b_addr            <=  i_axi_ingress_data;
          end
          `READ_BUF_A_ADDR: begin
            o_read_a_addr             <=  i_axi_ingress_data;
          end
          `READ_BUF_B_ADDR: begin
            o_read_b_addr             <=  i_axi_ingress_data;
          end
          `BUFFER_SIZE: begin
            o_buffer_size             <=  i_axi_ingress_data;
          end
          default: begin
          end
        endcase
        r_reg_write_stb                     <=  1;

        rd_state                            <=  FLUSH;
      end
      WRITE_CMD: begin
        r_cmd_enable_stb                    <=  1;
        o_dword_size                        <=  i_axi_ingress_data;

        //This could be set up in such a way that we presume both buffers are ready
        //r_update_buf_status                 <=  2'b00;
        r_update_buf_status                 <=  2'b11;

        r_reg_write_stb                     <=  1;
        rd_state                            <=  FLUSH;
      end
      READ_CMPLT: begin
        //The packet data should be up to the size of the data count of the FIFO
        if (r_egress_data_count < w_rcv_max_size) begin
          o_egress_stb                      <=  1;
          r_egress_data_count               <=  r_egress_data_count + 1;
          o_egress_data                     <=  i_axi_ingress_data;
        end
        else begin
          o_egress_activate                 <=  0;
          rd_state                          <=  FLUSH;
          r_rcv_cmplt_stb                   <=  1;
        end
      end
      FLUSH: begin
        if (!i_axi_ingress_valid) begin
          rd_state                          <=  IDLE;
        end
      default: begin
        if (!i_axi_ingress_valid) begin
          rd_state                          <=  IDLE;
        end
      end
    endcase
  end
end
always @ (posedge clk) begin
  if (rst) begin
    wr_state              <=  IDLE;
    r_wr_finished         <=  0;
    r_wr_hdr_index        <=  0;
    r_wr_data_count       <=  0;
    r_wr_hdr_type         <=  0;

    o_axi_egress_valid    <=  0;
    o_axi_egress_last     <=  0;
    o_axi_egress_data     <=  0;

  end
  else begin
    case (wr_state)
      IDLE: begin
        //Send Data when control sm gets something interesting
        r_wr_hdr_type     <=  0;
        r_wr_hdr_index    <=  0;

        if (w_wr_sm_en) begin
          r_wr_data_count <=  0;
          wr_state        <=  READY;
        end
      end
      READY: begin
        //Three different transactions are possible
        r_wr_hdr_index  <=  0;
        if (i_core_ready && i_axi_egress_ready) begin
          case (r_send_type)
            WR_TYPE_NONE: begin
            end
            WR_TYPE_CFG: begin
              r_wr_data_count       <=  0;
                r_wr_hdr_type       <=  {`PCIE_FMT_3DW_DATA, `PCIE_TYPE_MWR};
              wr_state              <=  SEND_WR_HDR;
            end
            WR_TYPE_DATA: begin
              if (i_ingress_ready && !o_ingress_activate) begin
                r_wr_data_count     <=  0;
                o_ingress_activate  <=  1;
              end
              if (o_ingress_activate) begin
                r_wr_hdr_type       <=  {`PCIE_FMT_3DW_DATA, `PCIE_TYPE_MWR};
                wr_state            <=  SEND_WR_HDR;
              end
            end
            WR_TYPE_DATA_REQ: begin
              r_wr_hdr_type         <=  {`PCIE_FMT_3DW_NO_DATA, `PCIE_TYPE_MRD};
              wr_state              <=  SEND_WR_HDR;
            end
          endcase
        end
      end
      SEND_WR_HDR: begin
        o_axi_egress_valid          <=  1;
        if (r_wr_hdr_index >= 2) begin
          case (r_send_type)
            WR_TYPE_CFG: begin
              wr_state                <=  SEND_CFG_DATA;
            end
            WR_TYPE_DATA: begin
              wr_state                <=  SEND_WR_DATA;
            end
            WR_TYPE_DATA_REQ: begin
              wr_state                <=  FINISHED;
              o_axi_egress_last       <=  1;
            end
            default: begin
              wr_state                <=  FINISHED;
              o_axi_egress_last       <=  1;
            end
          endcase
        end
        r_wr_hdr_index              <=  r_wr_hdr_index + 1;
        o_axi_egress_data           <=  r_rd_hdr[r_wr_hdr_index];
      end
      SEND_WR_DATA: begin
        o_ingress_stb               <=  1;
        o_axi_egress_data           <=  i_ingress_data;
        r_wr_data_count             <=  r_wr_data_count + 1;
        if ((r_wr_data_count + 1) >= i_ingress_size) begin
          o_axi_egress_last         <=  1;
          wr_state                  <=  FINISHED;
        end
      end
      SEND_CFG_DATA: begin
        o_axi_egress_data           <=  w_config_regs[r_wr_data_count];
        if (r_wr_data_count >= (`CONFIG_REGISTER_COUNT - 1)) begin
          o_axi_egress_last         <=  1;
          wr_state                  <=  FINISHED;
        end
      end
      WR_TYPE_DATA_REQ: begin
      end
      FINISH: begin
        o_axi_egress_valid          <=  0;
        r_wr_finished   <=  1;
        if (!w_wr_sm_en) begin
          wr_state                  <= IDLE;
        end
      end
    endcase
  end
end

endmodule
