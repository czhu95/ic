module DEWHITENING (
    input  wire           clk           , // Clock
    input  wire           rst_n         , // Asynchronous reset active low
    input  wire           data_in       ,
    input  wire           data_in_valid ,
    output reg  [7 : 0]   data_out      ,
    output reg  [1 : 0]   data_out_valid,
    output reg            fsc_end
);

    reg [2 : 0] in_bit_cnt, in_bit_cnt_nxt;
    reg [8 : 0] pin_ff     ;
    reg [7 : 0] pin_reg, pin_reg_nxt;
    reg [7 : 0] in_buff    ;
    reg [7 : 0] cnt, cnt_nxt;
    reg [1 : 0] phr_cnt, phr_cnt_nxt;
    reg [1 : 0] state, state_nxt;

    wire [8 : 0] pin_ff_nxt;
    wire [7 : 0] whitening_out;
    assign pin_ff_nxt = {(pin_ff[0] ^ pin_ff[5]), pin_ff[8 : 1]};
    assign whitening_out = pin_reg ^ in_buff;

    always @(posedge clk or negedge rst_n) begin : proc_update_states
        if(~rst_n) begin
            in_bit_cnt  <= {3{1'b 0}};
            pin_reg     <= {8{1'b 0}};
            cnt         <= {8{1'b 0}};
            phr_cnt     <= 2'b 00;
            state       <= 2'b 00;
        end else begin
            in_bit_cnt  <= in_bit_cnt_nxt;
            pin_reg     <= pin_reg_nxt;
            cnt         <= cnt_nxt;
            phr_cnt     <= phr_cnt_nxt;
            state       <= state_nxt;
        end
    end

    // pin_ff
    always @(posedge clk or negedge rst_n) begin : proc_update_pin
        if (~rst_n)
            pin_ff <= {9{1'b 1}};
        else if (~data_in_valid || fsc_end)
            pin_ff <= {9{1'b 1}};
        else
            pin_ff <= pin_ff_nxt;
    end

    // in_bit_cnt_nxt
    always @(*) begin : proc_input_state_control
        if (data_in_valid == 1'b 1) begin
            in_bit_cnt_nxt  <= in_bit_cnt + 3'h 1;
        end else begin
            in_bit_cnt_nxt  <= {3{1'b 0}};
        end
    end

    // pin_reg_nxt
    always @(*) begin : proc_pincode_control
        if (data_in_valid && in_bit_cnt == {3{1'b 0}})
            pin_reg_nxt <= pin_ff[7 : 0];
        else
            pin_reg_nxt <= pin_reg;
    end


    // in_buff
    always @(posedge clk or negedge rst_n) begin : proc_input_update
        if(~rst_n) begin
            in_buff <= {8{1'b 0}};
        end else if (data_in_valid && ~fsc_end) begin
            in_buff <= {data_in, in_buff[7 : 1]};
        end else
            in_buff <= in_buff;
    end

    // state_nxt;
    always @(*) begin : proc_state
        if (in_bit_cnt == 3'h 0)
            case (state)
                2'b 00 : state_nxt <= (data_in_valid && ~fsc_end) ? 2'b 01 : state;
                2'b 01 : state_nxt <= phr_cnt == 2'h 1 ? 2'b 10 : state;
                2'b 10 : state_nxt <= cnt == 8'h 01 ? 2'b 11 : state;
                2'b 11 : state_nxt <= cnt == 8'h 01 ? 2'b 00 : state;
            endcase
        else 
            state_nxt <= state;
    end
    
    // cnt_nxt, phr_cnt_nxt
    always @(*) begin : proc_cnt
        if (in_bit_cnt == 3'h 0 && data_in_valid && state != 2'h 0) begin
            if (state == 2'h 1) begin
                cnt_nxt <= (cnt == 8'h 00) ? whitening_out : cnt - 8'h 01;
                phr_cnt_nxt <= (phr_cnt == 2'h 0) ? 2'h 3 : phr_cnt - 2'h 1;
            end else begin
                cnt_nxt <= (cnt == 8'h 01 && state != 2'h 3) ? 8'h 2 : cnt - 8'h 01;
                phr_cnt_nxt <= 2'h 0;
            end
        end else begin
            cnt_nxt <= cnt;
            phr_cnt_nxt <= phr_cnt;
        end
    end

    always @(negedge clk or negedge rst_n) begin : proc_output
        if (~rst_n) begin
            data_out       <= 8'h 00;
            data_out_valid <= 2'h 0;
            fsc_end        <= 1'b 0;
        end else if (in_bit_cnt == 3'h 0 && data_in_valid && ~fsc_end) begin
            data_out       <= whitening_out;
            data_out_valid <= state;
            fsc_end <=  (state == 2'h 3 && cnt == 8'h 01) ? 1'b 1 : 1'b 0;
        end else begin
            data_out       <= 8'h 00;
            data_out_valid <= 2'h 0;
            fsc_end        <= 1'b 0;
        end
   end
endmodule
