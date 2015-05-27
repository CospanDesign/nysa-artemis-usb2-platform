//wb_artemis_sata.v
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
  Set the Vendor ID (Hexidecimal 64-bit Number)
  SDB_VENDOR_ID:0x800000000000C594

  Set the Device ID (Hexcidecimal 32-bit Number)
  SDB_DEVICE_ID:0x800000000000C594

  Set the version of the Core XX.XXX.XXX Example: 01.000.000
  SDB_CORE_VERSION:00.000.001

  Set the Device Name: 19 UNICODE characters
  SDB_NAME:wb_artemis_sata

  Set the class of the device (16 bits) Set as 0
  SDB_ABI_CLASS:0

  Set the ABI Major Version: (8-bits)
  SDB_ABI_VERSION_MAJOR:0x14

  Set the ABI Minor Version (8-bits)
  SDB_ABI_VERSION_MINOR:0x01

  Set the Module URL (63 Unicode Characters)
  SDB_MODULE_URL:http://www.example.com

  Set the date of module YYYY/MM/DD
  SDB_DATE:2015/03/25

  Device is executable (True/False)
  SDB_EXECUTABLE:True

  Device is readable (True/False)
  SDB_READABLE:True

  Device is writeable (True/False)
  SDB_WRITEABLE:True

  Device Size: Number of Registers
  SDB_SIZE:3
*/


module wb_artemis_sata (
  input               clk,
  input               rst,

  //Add signals to control your device here

  //Wishbone Bus Signals
  input               i_wbs_we,
  input               i_wbs_cyc,
  input       [3:0]   i_wbs_sel,
  input       [31:0]  i_wbs_dat,
  input               i_wbs_stb,
  output  reg         o_wbs_ack,
  output  reg [31:0]  o_wbs_dat,
  input       [31:0]  i_wbs_adr,

  //This interrupt can be controlled from this module or a submodule
  output  reg         o_wbs_int
  //output              o_wbs_int
);

//Local Parameters
localparam      CONTROL         = 32'h00000000;
localparam      STATUS          = 32'h00000001;

localparam      HD_STATUS       = 32'h00000002;
localparam      HD_REG_CMD      = 32'h00000003;

localparam      HD_REG_VALUE    = 32'h00000004;
localparam      HD_COMMAND      = 32'h00000005;
localparam      HD_ADDRESS      = 32'h00000006;
localparam      HD_SECTOR_COUNT = 32'h00000007;

localparam      HD_DATA         = 32'h00000008;


//Local Registers/Wires
reg   [31:0]    control;
wire  [31:0]    status;
//Submodules

sata_stack sata(
  .rst                    (rst                    ),   //reset
  .clk                    (clk                    ),   //clock used to run the stack
  .data_in_clk            (data_in_clk            ),
  .data_in_clk_valid      (data_in_clk_valid      ),
  .data_out_clk           (data_out_clk           ),
  .data_out_clk_valid     (data_out_clk_valid     ),

  .platform_ready         (platform_ready         ),   //the underlying physical platform is
  .linkup                 (linkup                 ),   //link is finished
  .sata_ready             (sata_ready             ),
  .sata_init              (sata_init              ),

  .send_sync_escape       (send_sync_escape       ),
  .user_features          (user_features          ),


  .busy                   (busy                   ),
  .error                  (error                  ),


  .write_data_en          (write_data_en          ),
  .single_rdwr            (single_rdwr            ),
  .read_data_en           (read_data_en           ),

  .send_user_command_stb  (send_user_command_stb  ),
  .soft_reset_en          (soft_reset_en          ),
  .command                (command                ),
  .pio_data_ready         (pio_data_ready         ),

  .sector_count           (sector_count           ),
  .sector_address         (sector_address         ),


  .dma_activate_stb       (dma_activate_stb       ),
  .d2h_reg_stb            (d2h_reg_stb            ),
  .pio_setup_stb          (pio_setup_stb          ),
  .d2h_data_stb           (d2h_data_stb           ),
  .dma_setup_stb          (dma_setup_stb          ),
  .set_device_bits_stb    (set_device_bits_stb    ),

  .dbg_send_command_stb   (                       ),
  .dbg_send_control_stb   (                       ),
  .dbg_send_data_stb      (                       ),

  .d2h_interrupt          (d2h_interrupt          ),
  .d2h_notification       (d2h_notification       ),
  .d2h_port_mult          (d2h_port_mult          ),
  .d2h_device             (d2h_device             ),
  .d2h_lba                (d2h_lba                ),
  .d2h_sector_count       (d2h_sector_count       ),
  .d2h_status             (d2h_status             ),
  .d2h_error              (d2h_error              ),

  .user_din               (user_din               ),
  .user_din_stb           (user_din_stb           ),
  .user_din_ready         (user_din_ready         ),
  .user_din_activate      (user_din_activate      ),
  .user_din_size          (user_din_size          ),

  .user_dout              (user_dout              ),
  .user_dout_ready        (user_dout_ready        ),
  .user_dout_activate     (user_dout_activate     ),
  .user_dout_stb          (user_dout_stb          ),
  .user_dout_size         (user_dout_size         ),


  .transport_layer_ready  (transport_layer_ready  ),
  .link_layer_ready       (link_layer_ready       ),
  .phy_ready              (phy_ready              ),



  .tx_dout                (tx_dout                ),
  .tx_isk                 (tx_isk                 ),
  .tx_comm_reset          (tx_comm_reset          ),
  .tx_comm_wake           (tx_comm_wake           ),
  .tx_elec_idle           (tx_elec_idle           ),

  .rx_din                 (rx_din                 ),
  .rx_isk                 (rx_isk                 ),
  .rx_elec_idle           (rx_elec_idle           ),
  .comm_init_detect       (comm_init_detect       ),
  .comm_wake_detect       (comm_wake_detect       ),
  .rx_byte_is_aligned     (rx_byte_is_aligned     ),



  .dbg_remote_abort       (                       ),
  .dbg_xmit_error         (                       ),
  .dbg_read_crc_error     (                       ),
                                                  
                                                  
  .dbg_pio_response       (                       ),
  .dbg_pio_direction      (                       ),
  .dbg_pio_transfer_count (                       ),
  .dbg_pio_e_status       (                       ),
                                                  
  .dbg_h2d_command        (                       ),
  .dbg_h2d_features       (                       ),
  .dbg_h2d_control        (                       ),
  .dbg_h2d_port_mult      (                       ),
  .dbg_h2d_device         (                       ),
  .dbg_h2d_lba            (                       ),
  .dbg_h2d_sector_count   (                       ),
                                                  
                                                  
                                                  
  .dbg_cl_if_ready        (                       ),
  .dbg_cl_if_activate     (                       ),
  .dbg_cl_if_size         (                       ),
  .dbg_cl_if_strobe       (                       ),
  .dbg_cl_if_data         (                       ),
                                                  
  .dbg_cl_of_ready        (                       ),
  .dbg_cl_of_activate     (                       ),
  .dbg_cl_of_strobe       (                       ),
  .dbg_cl_of_data         (                       ),
  .dbg_cl_of_size         (                       ),
                                                  
  .dbg_cc_lax_state       (                       ),
  .dbg_cr_lax_state       (                       ),
  .dbg_cw_lax_state       (                       ),
                                                  
  .dbg_t_lax_state        (                       ),
                                                  
  .dbg_li_lax_state       (                       ),
  .dbg_lr_lax_state       (                       ),
  .dbg_lw_lax_state       (                       ),
  .dbg_lw_lax_fstate      (                       ),


  .prim_scrambler_en      (1'b1                   ),
  .data_scrambler_en      (1'b1                   ),

  .dbg_ll_write_ready     (                       ),
  .dbg_ll_paw             (                       ),
  .dbg_ll_write_start     (                       ),
  .dbg_ll_write_strobe    (                       ),
  .dbg_ll_write_finished  (                       ),
  .dbg_ll_write_data      (                       ),
  .dbg_ll_write_size      (                       ),
  .dbg_ll_write_hold      (                       ),
  .dbg_ll_write_abort     (                       ),
                                                 
  .dbg_ll_read_start      (                       ),
  .dbg_ll_read_strobe     (                       ),
  .dbg_ll_read_data       (                       ),
  .dbg_ll_read_ready      (                       ),
  .dbg_ll_read_finished   (                       ),
  .dbg_ll_remote_abort    (                       ),
  .dbg_ll_xmit_error      (                       ),
                                                 
  .dbg_ll_send_crc        (                       ),


  .lax_state              (                       ),

  .dbg_detect_sync        (                       ),
  .dbg_detect_r_rdy       (                       ),
  .dbg_detect_r_ip        (                       ),
  .dbg_detect_r_ok        (                       ),
  .dbg_detect_r_err       (                       ),
  .dbg_detect_x_rdy       (                       ),
  .dbg_detect_sof         (                       ),
  .dbg_detect_eof         (                       ),
  .dbg_detect_wtrm        (                       ),
  .dbg_detect_cont        (                       ),
  .dbg_detect_hold        (                       ),
  .dbg_detect_holda       (                       ),
  .dbg_detect_align       (                       ),
  .dbg_detect_preq_s      (                       ),
  .dbg_detect_preq_p      (                       ),
  .dbg_detect_xrdy_xrdy   (                       ),

  .dbg_send_holda         (                       ),

  .slw_in_data_addra      (slw_in_data_addra      ),
  .slw_d_count            (slw_d_count            ),
  .slw_write_count        (slw_write_count        ),
  .slw_buffer_pos         (slw_buffer_pos         )
);



//Asynchronous Logic
//Synchronous Logic

always @ (posedge clk) begin
  if (rst) begin
    o_wbs_dat <= 32'h0;
    o_wbs_ack <= 0;
    o_wbs_int <= 0;
  end

  else begin
    //when the master acks our ack, then put our ack down
    if (o_wbs_ack && ~i_wbs_stb)begin
      o_wbs_ack <= 0;
    end

    if (i_wbs_stb && i_wbs_cyc) begin
      //master is requesting somethign
      if (!o_wbs_ack) begin
        if (i_wbs_we) begin
          //write request
          case (i_wbs_adr)
            CONTROL: begin
            end
            //add as many ADDR_X you need here
            default: begin
            end
          endcase
        end
        else begin
          //read request
          case (i_wbs_adr)
            CONTROL: begin
              o_wbs_dat <= ADDR_0;
            end
            default: begin
            end
          endcase
        end
        o_wbs_ack <= 1;
      end
    end
  end
end

endmodule
