module DEMODULATION(
  input      wire      clk,
  input      wire      rst,
  input      wire      data_in,
  input      wire      fsc_end,
  output     reg       data_out,
  output     reg       data_out_valid
  );

    reg            state, state_nxt;
    reg [79:0]     buffer, buffer_nxt;
    wire           match;
  
    parameter SHR = 80'hF3_98_AA_AA_AA_AA_AA_AA_AA_AA;
    assign match = (buffer == SHR);

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            buffer  <= {80{1'b1}};
        end else begin
            buffer  <= buffer_nxt;
        end
    end
 
    always @(negedge clk or negedge rst) begin
        if (~rst) begin
            state  <= 0;
        end else begin
            state  <= state_nxt;
        end
    end
  
    always @(*) begin : proc_buffer_control
        if (state == 2'b 00 || fsc_end) begin
            buffer_nxt <= {data_in, buffer[79 : 1]};
        end else begin
            buffer_nxt <= {80{1'b1}};
        end
    end
  
    always @(*) begin : proc_state_control
        case (state)
            0 : state_nxt <= (match)? 1 : state;
            1 : state_nxt <= (fsc_end)? 0 : state;
        endcase
    end

    always @(*) begin : proc_out_control
        data_out <= (state)? data_in : 0;
        data_out_valid <= state;
    end

endmodule
