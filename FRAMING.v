module FRAMING (
    input  wire       clk           , // Clock
    input  wire       rst_n         , // Asynchronous reset active low
    input  wire       frame_en      ,
    input  wire [7:0] data_in       ,
    input  wire       data_in_valid ,
    output reg        data_out      ,
    output reg        data_out_valid,
    output reg        frame_ready
);

    parameter [63:0] Preamble = 64'h AA_AA_AA_AA_AA_AA_AA_AA;
    parameter [15:0] SFD = 16'h F3_98;
    parameter DATA_W = 8, ADDR_W = 4, BUFF_L = 10, OUT_ADDR_W = 3;

    reg [1:0] state_ff, state_ff_nxt;
    reg [5:0] bit_ptr, bit_ptr_nxt;
    wire      fifo_rd_en, fifo_out, fifo_out_valid;

    reg [DATA_W - 1 : 0] mem_array  [0: 2**ADDR_W - 1];
    reg [ADDR_W - 1 : 0] rd_ptr, wr_ptr;
    reg [ADDR_W - 1 : 0] rd_ptr_nxt, wr_ptr_nxt;
    reg                  full_ff, empty_ff;
    reg                  full_ff_nxt, empty_ff_nxt;

    reg [    DATA_W - 1 : 0] out_buff    ;
    reg [OUT_ADDR_W - 1 : 0] out_cnt, out_cnt_nxt;
    reg [             1 : 0] out_state_ff, out_state_ff_nxt;
    wire                     fetch       ;

    // Update the states
    always @(posedge clk or negedge rst_n) begin : proc_reg_update
        if (~rst_n)    begin
            rd_ptr       <= {(ADDR_W){1'b 0}};
            wr_ptr       <= {(ADDR_W){1'b 0}};
            full_ff      <= 1'b 0;
            empty_ff     <= 1'b 1;
            out_cnt      <= {(OUT_ADDR_W){1'b 0}};
            out_state_ff <= 2'b 00;
            state_ff     <= 2'b 00;
            bit_ptr      <= {6{1'b 0}};
        end else begin
            rd_ptr       <= rd_ptr_nxt;
            wr_ptr       <= wr_ptr_nxt;
            empty_ff     <= empty_ff_nxt;
            full_ff      <= full_ff_nxt;
            out_cnt      <= out_cnt_nxt;
            out_state_ff <= out_state_ff_nxt;
            state_ff     <= state_ff_nxt;
            bit_ptr      <= bit_ptr_nxt;
        end
    end

    assign fetch      = (fifo_rd_en && out_state_ff == 2'b 00) || out_state_ff == 2'b 10;
    assign fifo_rd_en = (state_ff == 2'b 10) && (bit_ptr == 6'h 0F);

    // Control for rd/wr pointers
    // wt_ptr_nxt, rd_ptr_nxt, empty_ff_nxt, full_ff_nxt
    always @(*) begin
        if (fetch == 1'b 1 && data_in_valid == 1'b 0) begin
            wr_ptr_nxt   <= wr_ptr;
            if (~empty_ff) begin
                rd_ptr_nxt   <= (rd_ptr < BUFF_L - 1)? rd_ptr + 4'h 1: {(ADDR_W){1'b 0}};
                if ((rd_ptr + 1 == wr_ptr) || ((rd_ptr == BUFF_L- 1) && (wr_ptr == 0)))
                    empty_ff_nxt <= 1'b 1;
                else
                    empty_ff_nxt <= 1'b 0;
                full_ff_nxt  <= 1'b 0;
            end else begin
                rd_ptr_nxt   <= rd_ptr;
                empty_ff_nxt <= empty_ff;
                full_ff_nxt  <= full_ff;
            end
        end else if (fetch == 1'b 0 && data_in_valid == 1'b 1) begin
            rd_ptr_nxt   <= rd_ptr;
            if (~full_ff) begin
                wr_ptr_nxt   <= (wr_ptr < BUFF_L - 1)? wr_ptr + 4'h 1: {(ADDR_W){1'b 0}};
                if ((wr_ptr + 1 == rd_ptr) || ((wr_ptr == BUFF_L- 1) && (rd_ptr == 0)))
                    full_ff_nxt  <= 1'b 1;
                else
                    full_ff_nxt  <= 1'b 0;
                empty_ff_nxt <= 1'b 0;
            end else begin
                wr_ptr_nxt   <= wr_ptr;
                empty_ff_nxt <= empty_ff;
                full_ff_nxt  <= full_ff;
            end
        end else if (fetch == 1'b 1 && data_in_valid == 1'b 1 && ~empty_ff) begin
            rd_ptr_nxt   <= (rd_ptr < BUFF_L - 1)? rd_ptr + 4'h 1: {(ADDR_W){1'b 0}};
            wr_ptr_nxt   <= (wr_ptr < BUFF_L - 1)? wr_ptr + 4'h 1: {(ADDR_W){1'b 0}};
            full_ff_nxt  <= full_ff;
            empty_ff_nxt <= empty_ff;
        end else begin
            rd_ptr_nxt   <= rd_ptr;
            wr_ptr_nxt   <= wr_ptr;
            full_ff_nxt  <= full_ff;
            empty_ff_nxt <= empty_ff;
        end
    end

    // Update main memory
    // out_buff, mem_array[wr_ptr]
    always @(posedge clk) begin : proc_mem
        if (fetch && ~data_in_valid) begin
            mem_array[wr_ptr] <= mem_array[wr_ptr];
            if (out_state_ff[0] == 1'b 0 && ~empty_ff)
                out_buff          <= mem_array[rd_ptr];
            else
                out_buff          <= out_buff;
        end else if (~fetch && data_in_valid) begin
            out_buff          <= out_buff;
            if (~full_ff)
                mem_array[wr_ptr] <= data_in;
            else 
                mem_array[wr_ptr] <= mem_array[wr_ptr];
        end else if (fetch && data_in_valid) begin
            if (out_state_ff[0] == 1'b 0) begin
                if (empty_ff) begin
                    out_buff          <= data_in;
                    mem_array[wr_ptr] <= mem_array[wr_ptr];
                end else begin
                    out_buff          <= mem_array[rd_ptr];
                    mem_array[wr_ptr] <= data_in;
                end
            end else if (~full_ff) begin
                out_buff          <= out_buff;
                mem_array[wr_ptr] <= data_in;
            end
        end else begin
            out_buff          <= out_buff;
            mem_array[wr_ptr] <= mem_array[wr_ptr];
        end
    end

    // Control for output buffer pointers
    // out_cnt_nxt, out_state_ff_nxt
    always @(*) begin
        case (out_state_ff)
            2'b 00 : begin
                out_cnt_nxt <= {(OUT_ADDR_W){1'b 0}};
                if ((fifo_rd_en && ~empty_ff) || (fifo_rd_en && data_in_valid))
                    out_state_ff_nxt <= 2'b 01;
                else
                    out_state_ff_nxt <= 2'b 00;
            end
            2'b 01 : begin
                out_cnt_nxt <= out_cnt + 3'h 1;
                if (out_cnt == {{(OUT_ADDR_W - 1){1'b 1}}, 1'b 0})
                    out_state_ff_nxt <= 2'b 10;
                else
                    out_state_ff_nxt <= 2'b 01;
            end
            2'b 10 : begin
                out_cnt_nxt <= {(OUT_ADDR_W){1'b 0}};
                if (empty_ff == 1'b 1)
                    out_state_ff_nxt <= 2'b 00;
                else
                    out_state_ff_nxt <= 2'b 01;
            end
            default : begin
                out_cnt_nxt <= {(OUT_ADDR_W){1'b 0}};
                out_state_ff_nxt <= 2'b 00;
            end
        endcase
    end

    // bit_ptr_nxt, state_ff_nxt
    always @(*) begin : proc_state_control
        case (state_ff)
            2'b 00 : begin
                bit_ptr_nxt  <= {6{1'b 0}};
                if(frame_en == 1'b 1) begin
                    state_ff_nxt <= 2'b 01;
                end else begin
                    state_ff_nxt <= 2'b 00;
                end
            end
            2'b 01 : begin
                if(bit_ptr == 6'h 3F) begin
                    state_ff_nxt <= 2'b 10;
                    bit_ptr_nxt  <= {6{1'b 0}};
                end else begin
                    state_ff_nxt <= 2'b 01;
                    bit_ptr_nxt  <= bit_ptr + 6'h 1;
                end
            end
            2'b 10 : begin
                if(bit_ptr == 6'h 0F) begin
                    state_ff_nxt <= 2'b 11;
                    bit_ptr_nxt  <= {6{1'b 0}};
                end else begin
                    state_ff_nxt <= 2'b 10;
                    bit_ptr_nxt  <= bit_ptr + 6'h 1;
                end
            end
            2'b 11 : begin
                bit_ptr_nxt  <= {6{1'b 0}};
                if(data_out_valid == 1'b 1) begin
                    state_ff_nxt <= 2'b 11;
                end else begin
                    state_ff_nxt <= 2'b 00;
                end
            end
            default : begin
                state_ff_nxt <= 2'b 00;
                bit_ptr_nxt  <= {6{1'b 0}};
            end
        endcase
    end

    // data_out_valid, data_out
    always @(negedge clk or negedge rst_n) begin : proc_output_control
        if (~rst_n) begin
            data_out_valid <= 1'b 0;
            data_out       <= 1'b 0;
        end else begin
            case (state_ff)
                2'b 00 : begin
                    data_out_valid <= 1'b 0;
                    data_out       <= 1'b 0;
                end
                2'b 01 : begin
                    data_out_valid <= 1'b 1;
                    data_out       <= Preamble[bit_ptr];
                end
                2'b 10 : begin
                    data_out_valid <= 1'b 1;
                    data_out       <= SFD[bit_ptr];
                end
                2'b 11 : begin
                    data_out_valid <= (out_state_ff != 2'b00);
                    data_out       <= (out_state_ff == 2'b 00)? 1'b 0 : out_buff[out_cnt];
                end
                default : begin
                    data_out_valid <= data_out_valid;
                    data_out       <= data_out;
                end
            endcase
        end
    end

    always @(*) begin : proc_output_connect
        frame_ready <= state_ff == 2'b 00;
    end

endmodule
