module FIFO #(parameter DATA_W = 8, ADDR_W = 5, BUFF_L = 32, OUT_ADDR_W = 3) (
    input  wire              clk           , // Clock
    input  wire              rst_n         , // Asynchronous reset active low
    input  wire [DATA_W-1:0] fifo_in       ,
    input  wire              fifo_in_valid ,
    input  wire              rd_en         ,
    output reg               fifo_out      ,
    output reg               fifo_out_valid
);

    reg [DATA_W - 1 : 0] mem_array  [0: 2**ADDR_W - 1];
    reg [ADDR_W - 1 : 0] rd_ptr, wr_ptr;
    reg [ADDR_W - 1 : 0] rd_ptr_nxt, wr_ptr_nxt;
    reg                  full_ff, empty_ff;
    reg                  full_ff_nxt, empty_ff_nxt;

    reg [    DATA_W - 1 : 0] out_buff    ;
    reg [OUT_ADDR_W - 1 : 0] out_cnt, out_cnt_nxt;
    reg [             1 : 0] out_state_ff, out_state_ff_nxt;
    reg                      fetch       ;

    always @(posedge clk or negedge rst_n) begin : proc_reg_update
        if (~rst_n)    begin
            rd_ptr       <= {(ADDR_W){1'b 0}};
            wr_ptr       <= {(ADDR_W){1'b 0}};
            full_ff      <= 1'b 0;
            empty_ff     <= 1'b 1;
            out_cnt      <= {(OUT_ADDR_W){1'b 0}};
            out_state_ff <= 2'b 00;
        end else begin
            rd_ptr       <= rd_ptr_nxt;
            wr_ptr       <= wr_ptr_nxt;
            empty_ff     <= empty_ff_nxt;
            full_ff      <= full_ff_nxt;
            out_cnt      <= out_cnt_nxt;
            out_state_ff <= out_state_ff_nxt;
        end
    end

    // Control for fifo fetch flag
    always @(*) begin
        fetch <= (rd_en && out_state_ff == 2'b 00) || out_state_ff == 2'b 10;
    end

    // Control for rd/wr pointers
    // wr_ptr_nxt, rd_ptr_nxt, empty_ff_nxt, full_ff_nxt
    always @(*) begin
        if (fetch == 1'b 1 && fifo_in_valid == 1'b 0) begin
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
        end else if (fetch == 1'b 0 && fifo_in_valid == 1'b 1) begin
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
        end else if (fetch == 1'b 1 && fifo_in_valid == 1'b 1 && ~empty_ff) begin
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
        if (fetch && ~fifo_in_valid) begin
             mem_array[wr_ptr] <= mem_array[wr_ptr];
            if (out_state_ff[0] == 1'b 0 && ~empty_ff) begin
                out_buff          <= mem_array[rd_ptr];
            end else
                out_buff          <= {(DATA_W){1'b 0}};
        end else if (~fetch && fifo_in_valid) begin
            out_buff <= out_buff;
            if (~full_ff)
                mem_array[wr_ptr] <= fifo_in;
            else
                mem_array[wr_ptr] <= mem_array[wr_ptr];
        end else if (fetch && fifo_in_valid) begin
            if (out_state_ff[0] == 1'b 0) begin
                if (empty_ff) begin
                    out_buff          <= fifo_in;
                    mem_array[wr_ptr] <= mem_array[wr_ptr];
                end else begin
                    out_buff          <= mem_array[rd_ptr];
                    mem_array[wr_ptr] <= fifo_in;
                end
            end else if (~full_ff) begin
                out_buff          <= out_buff;
                mem_array[wr_ptr] <= fifo_in;
            end else begin
                out_buff          <= out_buff;
                mem_array[wr_ptr] <= mem_array[wr_ptr];
            end
        end else begin
            out_buff          <= out_buff;
            mem_array[wr_ptr] <= mem_array[wr_ptr];
        end
    end

    // Control for output buffer pointers
    always @(*) begin
        case (out_state_ff)
            2'b 00 : begin
                out_cnt_nxt <= {(OUT_ADDR_W){1'b 0}};

                if ((rd_en && ~empty_ff) || (rd_en && fifo_in_valid))
                    out_state_ff_nxt <= 2'b 01;
                else
                    out_state_ff_nxt <= 2'b 00;
            end
            2'b 01 : begin
                out_cnt_nxt <= out_cnt + 3'h 1;

                if (out_cnt == {{(OUT_ADDR_W - 1){1'b 1}}, 1'b 0}) begin
                    out_state_ff_nxt <= 2'b 10;
                end else begin
                    out_state_ff_nxt <= 2'b 01;
                end
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
    // Connect regs to output ports
    always @(negedge clk or negedge rst_n) begin
        if (~rst_n) begin
            fifo_out_valid <= 1'b 0;
            fifo_out       <= 1'b 0;
        end else begin
            fifo_out_valid <= (out_state_ff != 2'b00);
            fifo_out       <= (out_state_ff == 2'b 00)? 1'b 0 : out_buff[out_cnt];
        end
    end
endmodule
