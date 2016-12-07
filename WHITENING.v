module WHITENING (
    input  wire       clk           , // Clock
    input  wire       rst_n         , // Asynchronous reset active low
    input  wire       fifo_in       ,
    input  wire       fifo_in_valid ,
    input  wire       CRC_in        ,
    input  wire       CRC_in_valid  ,
    output reg  [7 : 0] data_out      ,
    output reg        data_out_valid
);

    reg [1 : 0] in_state_ff, in_state_ff_nxt;
    reg [2 : 0] in_bit_cnt, in_bit_cnt_nxt;
    reg [8 : 0] pin_ff     ;
    reg [7 : 0] pin_reg, pin_reg_nxt;
    reg [7 : 0] in_buff    ;

    wire [8 : 0] pin_ff_nxt;
    wire         data_in   ;


    assign pin_ff_nxt = {(pin_ff[0] ^ pin_ff[5]), pin_ff[8 : 1]};
    assign data_in = (fifo_in_valid)? fifo_in :
        (CRC_in_valid)? CRC_in : 1'b 0;

    // pin_ff
    always @(posedge clk or negedge rst_n) begin : proc_whitening
        if (~rst_n) begin
            pin_ff <= {9{1'b 1}};
        end else if (fifo_in_valid || CRC_in_valid) begin
            pin_ff <= pin_ff_nxt;
        end else if (in_state_ff == 2'b 00) begin
            pin_ff <= {9{1'b 1}};
        end else
            pin_ff <= pin_ff;
    end

    always @(posedge clk or negedge rst_n) begin : proc_update_states
        if(~rst_n) begin
            in_state_ff <= 2'b 00;
            in_bit_cnt  <= {3{1'b 0}};
            pin_reg     <= {3{1'b 0}};
        end else begin
            in_state_ff <= in_state_ff_nxt;
            in_bit_cnt  <= in_bit_cnt_nxt;
            pin_reg     <= pin_reg_nxt;
        end
    end

    // in_state_ff_nxt, in_bit_cnt_nxt
    always @(*) begin : proc_input_state_control
        case (in_state_ff)
            2'b 00 : begin
                // in_bit_cnt_nxt  <= {3{1'b 0}};
                if (fifo_in_valid == 1'b 1) begin
                    in_state_ff_nxt <= 2'b 01;
                    in_bit_cnt_nxt  <= 3'b001;
                end else begin
                    in_state_ff_nxt <= 2'b 00;
                    in_bit_cnt_nxt  <= {3{1'b 0}};
                end
            end
            2'b 01 : begin
                // in_bit_cnt_nxt  <= in_bit_cnt + 1;
                if (fifo_in_valid == 1'b 0) begin
                    in_bit_cnt_nxt  <= {3{1'b 0}};
                    in_state_ff_nxt <= 2'b 10;
                end else begin
                    in_state_ff_nxt <= 2'b 01;
                    in_bit_cnt_nxt  <= in_bit_cnt + 3'h 1;
                end
            end
            2'b 10 : begin
                if (CRC_in_valid == 1'b 1) begin
                    in_state_ff_nxt <= 2'b 11;
                    in_bit_cnt_nxt  <= 3'b 001;
                end else begin
                    in_state_ff_nxt <= 2'b 10;
                    in_bit_cnt_nxt  <= {3{1'b 0}};
                end
            end
            2'b 11 : begin
                in_bit_cnt_nxt  <= in_bit_cnt + 3'h 1;
                if (CRC_in_valid == 1'b 0)
                    in_state_ff_nxt <= 2'b 00;
                else
                    in_state_ff_nxt <= 2'b 11;
            end
            default : begin
                in_state_ff_nxt <= 2'b 00;
                in_bit_cnt_nxt  <= {3{1'b 0}};
            end
        endcase
    end

    // pin_reg_nxt
    always @(*) begin : proc_pincode_control
        if ((CRC_in_valid || fifo_in_valid) && in_bit_cnt == {3{1'b 0}})
            pin_reg_nxt <= pin_ff[7 : 0];
        else
            pin_reg_nxt <= pin_reg;
    end


    // in_buff
    always @(posedge clk or negedge rst_n) begin : proc_input_update
        if(~rst_n) begin
            in_buff <= {8{1'b 0}};
        end else if (fifo_in_valid || CRC_in_valid) begin
            in_buff <= {data_in, in_buff[7 : 1]};
        end else if (in_state_ff == 2'b 00) begin
            in_buff <= {8{1'b 0}};
        end else 
            in_buff <= in_buff;
    end

    always @(negedge clk or negedge rst_n) begin : proc_output_update
        if(~rst_n) begin
            data_out       <= {8{1'b 0}};
            data_out_valid <= 1'b 0;
        end else begin
            data_out       <= pin_reg ^ in_buff;
            data_out_valid <= ((in_state_ff == 2'b 01 || in_state_ff == 2'b 11) && (in_bit_cnt == {3{1'b 0}}))? 1'b 1 : 1'b 0;
        end
    end
endmodule
