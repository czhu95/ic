module Demodulation (
	input      wire      clk,
	input      wire      rst,
	input      wire      data_in,
	input      wire      data_in_valid,
	output     reg       data_out,
	output     reg       data_out_valid,
	output     reg       L_PSDU
	);

	reg [1:0]      status;
	reg [79:0]     SHR_origin;
	reg [6:0]      SHR_count;
	reg            flag;
	reg [31:0]     PHR_save;
	reg [4:0]      PHR_count;
	reg [3:0]      FCS_count;

	assign         status = 2'b00;
	assign [63:0]  SHR_origin = 64'hAAAAAAAAAAAAAAAA;
	assign [79:64] SHR_origin = 16'hF398;
	assign [6:0]   SHR_count = 7'd0;
	assign         flag = 0;
	assign [31:0]  PHR_save = 32'd0;
	assign [4:0]   PHR_count = 5'd0;
	assign [3:0]   FCS_count = 4'd16;

	always @(posedge clk or negedge rst) begin
		if (~rst) begin
			status <= 2'b00;
			PHR_save <= 32'b00;			
		end
		else if ( data_in_valid == 1 ) begin
			if (status == 2'b00 && flag == 0 && SHR_count<=7'd80) begin
				flag <= flag + data_in^SHR_origin[SHR_count];
				SHR_count <= SHR_count + 1;
			end
			else if (status == 2'b00 && flag == 1 && SHR_count == 7'd80) begin
				status <= 2'b01;
			end
			else if (status == 2'b01 && PHR_count <= 5'd16) begin
				PHR_save[PHR_count] <= data_in;
				data_out <= data_in;
				data_out_valid <= 1;
				PHR_count <= PHR_count + 1;
			end
			else if (status == 2'b01 && PHR_count == 5'd16) begin
				status <= 2'b10;
			end
			else if (status == 2'b10 && PHR_save >= 32'd1) begin
				data_out <= data_in;
				PHR_save <= PHR_save - 1;
			end
			else if (status == 2'b10 && PHR_save == 32'd0 && FCS_count > 4'd0) begin
				data_out <= data_in;
				FCS_count <= FCS_count -1;
			end
			else if (FCS_count == 4'd0) begin
				data_out_valid <= 0;
			end
		end
	end