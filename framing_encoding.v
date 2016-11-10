module framing_encoding (
	input  wire       clk                       , // Clock
	input  wire       reset_n                   , // Asynchronous reset active low
	input  wire [7:0] phr_psdu_in               ,
	input  wire       phr_psdu_in_valid         ,
	output wire       framing_encoding_out      ,
	output wire       framing_encoding_out_valid
);
	wire       fifo_rd_en, fifo_out, fifo_out_valid, crc_out, crc_out_valid, whitening_out_valid;
	wire [7:0] whitening_out;

	FIFO #(
		.ADDR_W(4 ),
		.BUFF_L(16)
	) fifo (
		.clk           (clk              ),
		.rst_n         (reset_n          ),
		.fifo_in       (phr_psdu_in      ),
		.fifo_in_valid (phr_psdu_in_valid),
		.rd_en         (fifo_rd_en       ),
		.fifo_out      (fifo_out         ),
		.fifo_out_valid(fifo_out_valid   )
	);

	CRC crc (
		.clk           (clk           ),
		.rst_n         (reset_n       ),
		.data_in       (fifo_out      ),
		.data_in_valid (fifo_out_valid),
		.data_out      (crc_out       ),
		.data_out_valid(crc_out_valid )
	);

	WHITENING whitening (
		.clk           (clk                ),
		.rst_n         (reset_n            ),
		.fifo_in       (fifo_out           ),
		.fifo_in_valid (fifo_out_valid     ),
		.CRC_in        (crc_out            ),
		.CRC_in_valid  (crc_out_valid      ),
		.data_out      (whitening_out      ),
		.data_out_valid(whitening_out_valid)
	);

	FRAMING framing (
		.clk           (clk                       ),
		.rst_n         (reset_n                   ),
		.frame_en      (phr_psdu_in_valid         ),
		.data_in       (whitening_out             ),
		.data_in_valid (whitening_out_valid       ),
		.data_out      (framing_encoding_out      ),
		.data_out_valid(framing_encoding_out_valid),
		.frame_ready   (fifo_rd_en                )
	);
endmodule