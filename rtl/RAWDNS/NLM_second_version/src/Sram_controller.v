/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/8
 *   Version:    v1.0
 *   Note:       Sram_controller
 *
 *********************************************************************/

module Sram_controller #(parameter      BLOCK_RADIUS        =       2,
                                        WIN_RADIUS          =       6,
                                        ADDR_WIDTH          =       12,
                                        IMAGE_WIDTH         =       4032,
                                        IMAGE_HEIGHT        =       3024,
                                        DATA_WIDTH          =       12)
            (
                    clk,
                    rst_n,
                    valid_i,
                    en_i,
                    frame_sync_i,
                    line_sync_i,
                    sram_rden_o,
                    sram_wren_o,
                    sram_addr_o,
                    head_num_o,
                    valid_o
            );
        //根据行场同步信号，生成SRAM阵列的地址信号以及使能信号，同时标注首位
        parameter ROW_PARA              =       (IMAGE_HEIGHT + BLOCK_RADIUS + WIN_RADIUS) % SRAM_SIZE                                          ;
        parameter SRAM_SIZE             =       2 * (BLOCK_RADIUS + WIN_RADIUS + 1)                                     ;//18 SRAM
        parameter STATE_WIDTH           =       3                                                                       ;
        parameter IDLE                  =       3'd0                                                                    ;//waiting for frame_ref
        parameter INIT                  =       3'd1                                                                    ;//Accepete line_ref, restoring the first few lines
        parameter PIXEL                 =       3'd2                                                                    ;//transfer the input pixels
        parameter NORMAL                =       3'd3                                                                    ;//Normal process
        parameter POST                  =       3'd4                                                                    ;//All lines readed,process the last line
        parameter START_PIX             =       SRAM_SIZE / 2                                                           ;//9 start to get original pixel
        parameter START_CAL             =       SRAM_SIZE - 1                                                           ;//17 start to process
        parameter INIT_RDEN             =       2**SRAM_SIZE - 1 - 2**START_CAL                                         ;//18'b0111_1111_1111_1111_11
        parameter RDEN_END              =       2**SRAM_SIZE - 1 - 2**ROW_PARA                                          ;//18'b1111_1111_0_1111_1111(IF ROW_PARA = 0)
        parameter REG_NUM               =       WIN_RADIUS + 2                                                          ;//8

        input                                                           en_i                                            ;
        input                                                           valid_i                                         ;
        input                                                           frame_sync_i                                    ;
        input                                                           line_sync_i                                     ;
        input                                                           clk                                             ;
        input                                                           rst_n                                           ;
        output                                                          valid_o                                         ;
        output      [SRAM_SIZE - 1              :0]                     sram_rden_o                                     ;
        output      [SRAM_SIZE - 1              :0]                     sram_wren_o                                     ;
        output      [ADDR_WIDTH - 1             :0]                     sram_addr_o                                     ;
        output      [4                          :0]                     head_num_o                                      ;

        reg                                             sram_rden_o                     ;
        reg                                             sram_wren_o                     ;
        reg                                             sram_addr_o                     ;
        reg                                             head_num_o                      ;

        reg         [STATE_WIDTH-1              :0]     state_r                         ;//FSM
        reg         [STATE_WIDTH-1              :0]     next_state_r                    ;//next_FSM
        reg         [15                         :0]     line_cnt                        ;          
        reg                                             valid_r                         ;
        reg                                             valid    [REG_NUM - 1 : 0]      ;

        //FSM transform 
        always @(posedge clk or negedge rst_n) begin
                if(!rst_n)      begin
                        state_r <= IDLE;
                end
                else begin
                        state_r <= next_state_r;
                end
        end

        always @( *) begin
        case(state_r) 
                IDLE:           begin
                        if(en_i & frame_sync_i & line_sync_i)
                                next_state_r = INIT;
                        else
                                next_state_r = IDLE;
                end
                INIT:           begin
                        if(line_sync_i & (line_cnt == START_PIX))
                                next_state_r = PIXEL;
                        else
                                next_state_r = INIT;
                end
                PIXEL:          begin
                        if(line_sync_i & (line_cnt == START_CAL))
                                next_state_r = NORMAL;
                        else
                                next_state_r = PIXEL;
                end
                NORMAL:         begin
                        if(!valid_i & (line_cnt == IMAGE_HEIGHT))
                                next_state_r = POST;
                        else 
                                next_state_r = NORMAL;
                end
                POST:           begin
                        if((sram_rden_o == RDEN_END) & (sram_addr_o == IMAGE_WIDTH - 1))
                                next_state_r = IDLE;
                        else 
                                next_state_r = POST;
                end
        endcase
        end

        //valid
        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)
                        valid_r <= 0;
                else if((state_r == INIT) & (next_state_r == PIXEL))
                        valid_r <= 1;
                else if((state_r == POST) & (sram_rden_o == RDEN_END) & (sram_addr_o == IMAGE_WIDTH - 1))
                        valid_r <= 0;
                else
                        valid_r <= valid_r;
        end
        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)
                        valid[0] <= 0;
                else
                        valid[0] <= valid_r;
        end
        genvar i;
        generate for(i = 1; i < REG_NUM; i = i + 1)     begin
                always @(posedge clk or negedge rst_n)  begin
                        if(!rst_n)
                                valid[i] <= 0;
                        else
                                valid[i] <= valid[i - 1];
                end
        end
        endgenerate
        assign valid_o = valid[REG_NUM - 1];

        //output
        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)
                        line_cnt <= 0;
                else if(line_sync_i & frame_sync_i & en_i)
                        line_cnt <= 1;
                else if(line_sync_i)
                        line_cnt <= line_cnt + 1;
                else
                        line_cnt <= line_cnt;
        end

        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)
                        sram_wren_o <= 0;
                else if(!valid_i)
                        sram_wren_o <= 0;
                else if((state_r == IDLE) & (next_state_r == INIT))
                        sram_wren_o <= 1;
                else if(state_r == POST)
                        sram_wren_o <= 0;
                else if(line_sync_i)
                        sram_wren_o <= {sram_wren_o[SRAM_SIZE - 2 : 0],sram_wren_o[SRAM_SIZE - 1]};
                else
                        sram_wren_o <= sram_wren_o;
        end
        
        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)      begin
                        sram_rden_o <= 0;
                end
                else if((state_r == INIT) & (next_state_r == PIXEL))    begin
                        sram_rden_o <= 1;
                end   
                else if((state_r == PIXEL) & (next_state_r == NORMAL))    begin
                        sram_rden_o <= INIT_RDEN;
                end
                else if(state_r == INIT)        begin
                        sram_rden_o <= 0;
                end
                else if(line_sync_i)    begin
                        sram_rden_o <= {sram_rden_o[SRAM_SIZE - 2 : 0],sram_rden_o[SRAM_SIZE - 1]};
                end
                else if((state_r == NORMAL) & (next_state_r == POST))   begin
                        sram_rden_o <= {sram_rden_o[SRAM_SIZE - 2 : 0],sram_rden_o[SRAM_SIZE - 1]};
                end
                else if((state_r == POST) & (sram_addr_o == IMAGE_WIDTH - 1))        begin
                        if(sram_rden_o == RDEN_END)     begin
                                sram_rden_o <= 0;
                        end
                        else    begin
                                sram_rden_o <= {sram_rden_o[SRAM_SIZE - 2 : 0],sram_rden_o[SRAM_SIZE - 1]};
                        end
                end
                else    begin
                        sram_rden_o <= sram_rden_o;
                end
        end

        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)      begin
                        head_num_o <= 0;
                end   
                else if((state_r == INIT) & (next_state_r == PIXEL))    begin
                        head_num_o = (START_PIX + 1 < SRAM_SIZE) ? (START_PIX + 1) : (START_PIX - (SRAM_SIZE - 1));
                end
                else if((state_r == INIT) & (next_state_r == NORMAL))    begin
                        head_num_o <= (START_CAL + 1 < SRAM_SIZE) ? (START_CAL + 1) : (START_CAL - (SRAM_SIZE - 1));
                end
                else if(state_r == INIT)        begin
                        head_num_o <= 0;
                end
                else if(line_sync_i)    begin
                        head_num_o <= (head_num_o + 1 < SRAM_SIZE) ? (head_num_o + 1) : (head_num_o - (SRAM_SIZE - 1));
                end
                else if((state_r == NORMAL) & (next_state_r == POST))   begin
                        head_num_o <= (head_num_o + 1 < SRAM_SIZE) ? (head_num_o + 1) : (head_num_o - (SRAM_SIZE - 1));
                end
                else if((state_r == POST) & (sram_addr_o == IMAGE_WIDTH - 1))        begin
                        if(sram_rden_o == RDEN_END)     begin
                                head_num_o <= 0;
                        end
                        else    begin
                                head_num_o <= (head_num_o + 1 < SRAM_SIZE) ? (head_num_o + 1) : (head_num_o - (SRAM_SIZE - 1));
                        end
                end
                else    begin
                        head_num_o <= head_num_o;
                end
        end

        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)
                        sram_addr_o <= 0;
                else if(state_r == IDLE)
                        sram_addr_o <= 0;
                else if(line_sync_i)
                        sram_addr_o <= 0;
                else if((state_r == NORMAL) & (valid_i == 0))
                        sram_addr_o <= 0;
                else if((state_r == POST) & (sram_addr_o == IMAGE_WIDTH - 1))
                        sram_addr_o <= 0;
                else   
                        sram_addr_o <= sram_addr_o + 1;
        end

endmodule