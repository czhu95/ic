module CRC (
	input  wire clk           , // Clock
	input  wire rst_n         , // Asynchronous reset active low
	input  wire data_in       ,
	input  wire data_in_valid ,
	output reg  data_out      ,
	output reg  data_out_valid
);

	reg  [ 3 : 0] out_ptr, out_ptr_nxt;
	reg  [ 1 : 0] state_ff, state_ff_nxt;
	reg  [15 : 0] ff      ;
	wire [15 : 0] next_ff ;

	assign {next_ff[14:11], next_ff[9:4], next_ff[2:0]} = {ff[15:12], ff[10:5], ff[3:1]};
	assign next_ff[3]  = ff[4] ^ next_ff[15];
	assign next_ff[10] = ff[11] ^ next_ff[15];
	assign next_ff[15] = ff[0] ^ data_in;

	always @(posedge clk or negedge rst_n) begin : proc_ff
		if(~rst_n) begin
			ff <= {16{1'b 1}};
		end else if (data_in_valid == 1'b 0 && state_ff == 2'b 00) begin
			ff <= {16{1'b 1}};
		end else if (data_in_valid == 1'b 1) begin
			// ff <= {16{1'b 1}};
			ff <= next_ff;
		end
	end

	always @(posedge clk or negedge rst_n) begin : proc_state_update
		if(~rst_n) begin
			out_ptr  <= {4{1'b 0}};
			state_ff <= 2'b 00;
		end else begin
			out_ptr  <= out_ptr_nxt;
			state_ff <= state_ff_nxt;
		end
	end

	always @(*)	begin
		case (state_ff)
			2'b 00 : begin
				out_ptr_nxt  <= {4{1'b 0}};
				if (data_in_valid == 1'b 1)
					state_ff_nxt <= 2'b 01;
				else
					state_ff_nxt <= 2'b 00;
			end

			2'b 01 : begin
				out_ptr_nxt  <= {4{1'b 0}};
				if (data_in_valid == 1'b 0)
					state_ff_nxt <= 2'b 10;
				else
					state_ff_nxt <= 2'b 01;
			end

			2'b 10 : begin
				if (out_ptr == {4{1'b 1}}) begin
					state_ff_nxt <= 2'b 00;
					out_ptr_nxt  <= {4{1'b 0}};
				end else begin
					state_ff_nxt <= 2'b 10;
					out_ptr_nxt  <= out_ptr + 1;

				end
			end
			default : begin
				state_ff_nxt <= 2'b 00;
				out_ptr_nxt  <= {4{1'b 0}};
			end
		endcase
	end

	always @(negedge clk or negedge rst_n) begin : proc_out
		if (~rst_n) begin
			data_out       <= 1'b 0;
			data_out_valid <= 1'b 0;
		end else begin
			data_out       <= (state_ff == 2'b 10)? ~ff[out_ptr] : 1'b 0;
			data_out_valid <= state_ff == 2'b 10;
		end
	end
endmodule