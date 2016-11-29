module framing_decoding (
	input  wire       clk                       , // Clock
	input  wire       reset_n                   , // Asynchronous reset active low
	input  wire       data_in,
	output wire [7:0] data_out,
	output wire [1:0]      data_out_valid
);
    wire fsc_end;
    wire dem_out, dem_out_valid;
    DEMODULATION u0Demodulation(
        .clk    (clk),
        .rst    (reset_n),
        .data_in    (data_in),
        .fsc_end    (fsc_end),
        .data_out   (dem_out),
        .data_out_valid    (dem_out_valid)
    );
    
    DEWHITENING u0Dewhitening(
        .clk        (clk),
        .rst_n      (reset_n),
        .data_in    (dem_out),
        .data_in_valid (dem_out_valid),
        .data_out   (data_out),
        .data_out_valid (data_out_valid),
        .fsc_end    (fsc_end)
    );

endmodule
