//-----------------------------------------------------------------------------
//
// Jonathan Westhues, April 2006
//-----------------------------------------------------------------------------

module hi_enio(
    pck0, ck_1356meg, ck_1356megb,
    pwr_lo, pwr_hi, pwr_oe1, pwr_oe2, pwr_oe3, pwr_oe4,
    adc_d, adc_clk,
    ssp_frame, ssp_din, ssp_dout, ssp_clk,
    cross_hi, cross_lo,
    dbg,
    xcorr_is_848, snoop, xcorr_quarter_freq, // not used.
    conf_enio, divisor
);
    input pck0, ck_1356meg, ck_1356megb;
    output pwr_lo, pwr_hi, pwr_oe1, pwr_oe2, pwr_oe3, pwr_oe4;
    input [7:0] adc_d;
    output adc_clk;
    input ssp_dout;
    output ssp_frame, ssp_din, ssp_clk;
    input cross_hi, cross_lo;
    output dbg;
    input xcorr_is_848, snoop, xcorr_quarter_freq; // not used.
    input [7:0] conf_enio, divisor;

// We are only snooping, all off.
assign pwr_hi  = 1'b0;// ck_1356megb & (~snoop);
assign pwr_oe1 = 1'b0;
assign pwr_oe2 = 1'b0;
assign pwr_oe3 = 1'b0;
assign pwr_oe4 = 1'b0;

reg ssp_clk = 1'b0;
reg ssp_frame;
reg adc_clk;
reg [7:0] adc_d_out = 8'd0;
reg [7:0] ssp_cnt = 8'd0;
reg [7:0] pck_divider = 8'd0;
reg ant_lo = 1'b0;
reg bit_to_send = 1'b0;

always @(ck_1356meg, pck0) // should synthetisize to a mux..
  begin
    if(conf_enio[0] == 1'b1) // HF
    begin
  	  adc_clk = ck_1356meg;
	    ssp_clk = ~ck_1356meg;
    end
    else if(conf_enio[0] == 1'b0) // LF
     begin
 	    adc_clk = pck0;
 	    ssp_clk = ~pck0;
     end
  end

// reg [1:0] cnt = 2'b0;
//
// always @(pck0)
//  begin
//    cnt <= cnt + 1;
//      if(cnt[1:0] == 2'b10)
//        begin
//          cnt[1:0] <= 2'b00;
//          ssp_clk <= ~ssp_clk;//ck_1356meg;
//        end
//  end

reg [7:0] cnt_test = 8'd0; // test

always @(posedge pck0)
begin
  if (conf_enio[0] == 1'b0) // LF
  begin
     if(pck_divider == divisor[7:0])
      begin
        pck_divider <= 8'd0;
        ant_lo <= !ant_lo;
      end
    else
    begin
      pck_divider <= pck_divider + 1;
    end
  end
  else
  begin
    ant_lo <= 1'b0;
  end
end

always @(posedge ssp_clk) // == pck0 (lf) ~1356 (hf)
begin
  if(ssp_cnt[7:0] == 8'd255) // SSP counter for divides.
    ssp_cnt[7:0] <= 8'd0;
  else
    ssp_cnt <= ssp_cnt + 1;

  if (conf_enio[0] == 1'b1) // HF
    begin
      if((ssp_cnt[2:0] == 3'b000) && !ant_lo) // To set frame  length
        begin
          adc_d_out[7:0] = adc_d; // disable for test
          bit_to_send = adc_d_out[0];
          ssp_frame <= 1'b1;
        end
      else
        begin
          adc_d_out[6:0] = adc_d_out[7:1];
          adc_d_out[7] = 1'b0; // according to old lf_read.v comment prevents gliches if not set.
          bit_to_send = adc_d_out[0];
          ssp_frame <= 1'b0;
        end
      end
  else if (conf_enio[0] == 1'b0) // LF
    begin 
      if((pck_divider == 8'd7) && !ant_lo) // To set frame  length
        begin
          adc_d_out[7:0] = adc_d;
          bit_to_send = adc_d_out[7];
        end
      else // send 8 - 15
      begin
        adc_d_out[7:1] = adc_d_out[6:0];
        adc_d_out[0] = 1'b0; // according to old lf_read.v comment prevents gliches if not set.
        bit_to_send = adc_d_out[7];
      end
      ssp_frame <= (pck_divider[7:0] == 8'd7) && !ant_lo; // Hackish way as frame goes up at END of time step (we want it up at 4'b1000)
    end
  end

assign ssp_din = bit_to_send && !ant_lo;//bit_to_send && !ant_lo; // && .. not needed i guess?

assign pwr_lo = ant_lo;
      

endmodule
