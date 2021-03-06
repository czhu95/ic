`timescale 1us/100ns

module framing_encoding_test;

     wire    [7:0]    out;
     wire    [1:0]         out_valid;
     reg     [7:0]    phr_psdu_in;
     reg              phr_psdu_in_valid;
     reg              clk;
     reg              reset_n;
 
 
 

framing_encoding u0framing_encoding(
    .framing_encoding_out        (framing_encoding_out),
    .framing_encoding_out_valid  (framing_encoding_out_valid),
    .phr_psdu_in                 (phr_psdu_in),
    .phr_psdu_in_valid           (phr_psdu_in_valid),
    .clk                         (clk),
    .reset_n                     (reset_n)
);

framing_decoding u0framing_decoding(
    .data_out        (out),
    .data_out_valid  (out_valid),
    .data_in                 (framing_encoding_out),
    .clk                         (clk),
    .reset_n                     (reset_n)
);


// stop simulation after 20000us
  initial 
    begin
    #20000 $finish;
    end

  initial
    begin
        $dumpfile("tb.vcd");
        $dumpvars(0,framing_encoding_test);
    end

// generate data input signal
  initial 
    begin
             phr_psdu_in=8'h00;
        #500 phr_psdu_in=8'h07;
        #100 phr_psdu_in=8'h03;
        #100 phr_psdu_in=8'h01;
        #100 phr_psdu_in=8'h05;
        #100 phr_psdu_in=8'h21;
        #100 phr_psdu_in=8'h43;
        #100 phr_psdu_in=8'h65;
        #100 phr_psdu_in=8'h87;
    end

// generate phr_psdu_in_valid signal
  initial 
    begin
             phr_psdu_in_valid =1'b0;
        #500 phr_psdu_in_valid =1'b1;
        #800 phr_psdu_in_valid =1'b0;
    end
    
// generate clk signal
  initial 
    begin
        clk=1'b0;
    end
always #50 clk=~clk;

// generate resrt_n signal
  initial 
    begin
               reset_n=1'b1;
        #  520 reset_n=1'b0;
        #  20  reset_n=1'b1;
    end

endmodule
