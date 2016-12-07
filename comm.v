

module comm (

     output wire    [7:0]    out,
     output wire    [1:0]         out_valid,
     input wire    [7:0]    phr_psdu_in,
     input wire       phr_psdu_in_valid,
     input wire       sysclk,
     input wire       iclk,
     input wire       reset_n
);

wire framing_encoding_out;
wire framing_encoding_out_valid;
wire clk;
 
debounce u0debounce(
    .i_clk(sysclk),
    .i_rst_n(reset_n),
    .i_key(iclk),
    .o_key_val(clk)
)

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

endmodule
