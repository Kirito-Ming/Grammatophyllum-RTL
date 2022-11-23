/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/17
 *   Version:    v1.0
 *   Note:       output_ctrl
 *
 *********************************************************************/

module output_ctrl #(parameter  
                        SUM_WIDTH       =  26,
                        DATA_WIDTH      =  12,
                        IMAGE_WIDTH     =  1920,
                        IMAGE_HEIGHT    =  1080,
                        BLOCK_RADIUS    =  2,
                        WIN_RADIUS      =  6
            )
            (
                clk,
                valid_i,
                rst_n,
                pix_sum_i,
                weight_sum_i,
                pix_i,                                              //与权重和数据对齐的原像素流
                pix_original,                                       //与去噪像素流对齐的原像素流
                pix_denoise,
                valid_o,
                line_sync_o,
                frame_sync_o
            );
    //输入是已经经过对齐的权重和与原像素流以及valid信号，对权重和进行判断后进行中心权重的计算与累加

    parameter                   STATE_WIDTH     =           3                               ;
    parameter                   IDLE            =           3'd0                            ;
    parameter                   FRONT           =           3'd1                            ;
    parameter                   NORMAL          =           3'd2                            ;
    parameter                   POST            =           3'd4                            ;
    parameter                   START_LINE      =           BLOCK_RADIUS + WIN_RADIUS       ;//8

    input                                                                       clk                                         ;
    input                                                                       rst_n                                       ;
    input                                                                       valid_i                                     ;
    input                       [SUM_WIDTH - 1                          :0]     pix_sum_i                                   ;
    input                       [SUM_WIDTH - DATA_WIDTH - 1             :0]     weight_sum_i                                ;
    input                       [DATA_WIDTH - 1                         :0]     pix_i                                       ; 
    output                      [DATA_WIDTH - 1                         :0]     pix_original                                ; 
    output                      [DATA_WIDTH - 1                         :0]     pix_denoise                                 ;
    output                                                                      valid_o                                     ;
    output                                                                      frame_sync_o                                ;
    output                                                                      line_sync_o                                 ;

    reg                                                                         pix_denoise                                 ;

    wire          signed        [SUM_WIDTH                              :0]     a_temp         [DATA_WIDTH - 1:0]           ; 
    wire                        [2 * DATA_WIDTH - 1                     :0]     z_temp         [DATA_WIDTH - 1:0]           ;
    wire                        [SUM_WIDTH - 1                          :0]     b_temp         [DATA_WIDTH - 1:0]           ;
    wire                        [8                                      :0]     center_weight                               ;

    wire                        [SUM_WIDTH - DATA_WIDTH - 1             :0]     weight_sum_final                            ;
    wire                        [SUM_WIDTH - 1                          :0]     pix_sum_final                               ;
    wire                        [SUM_WIDTH - 1                          :0]     weight_sum_shift                            ;
    reg                         [DATA_WIDTH - 1                         :0]     pix_shift      [DATA_WIDTH - 1:0]           ; 
    reg                         [STATE_WIDTH - 1                        :0]     state_r                                     ;
    reg                         [STATE_WIDTH - 1                        :0]     next_state_r                                ;
    wire                        [DATA_WIDTH - 1                         :0]     pix_temp                                    ;
    reg                                                                         valid_shift    [DATA_WIDTH - 1:0]           ;
    reg                         [11                                     :0]     line_cnt                                    ;
    reg                         [11                                     :0]     column_cnt                                  ;

    //中心点权重计算，并加回sum中
    assign center_weight = (weight_sum_i < 4) ? 4 : ((weight_sum_i > 472) ? 320 : 256);
    assign weight_sum_final = weight_sum_i + center_weight;
    assign weight_sum_shift = weight_sum_final << DATA_WIDTH;
    assign pix_sum_final = pix_sum_i + center_weight * pix_i;

    //cordic除法获取去噪像素流
    cordic_divider #(.SUM_WIDTH(SUM_WIDTH),.DATA_WIDTH(DATA_WIDTH),.ITER(1))
    u_cordic_divider(
        .clk(clk),
        .rst_n(rst_n),
        .a_i(pix_sum_final),
        .b_i(weight_sum_shift),
        .z_i(0),
        .a_o(a_temp[0]),
        .b_o(b_temp[0]),
        .z_o(z_temp[0])
    );
    genvar i;
    generate for(i = 1; i < DATA_WIDTH; i = i + 1)        begin
        cordic_divider #(.SUM_WIDTH(SUM_WIDTH),.DATA_WIDTH(DATA_WIDTH),.ITER(i + 1))
        u_cordic_divider(
            .clk(clk),
            .rst_n(rst_n),
            .a_i(a_temp[i - 1]),
            .b_i(b_temp[i - 1]),
            .z_i(z_temp[i - 1]),
            .a_o(a_temp[i]),
            .b_o(b_temp[i]),
            .z_o(z_temp[i])
        );
    end
    endgenerate

    //原像素流对齐
    always @(posedge clk or negedge rst_n)  begin
            if(!rst_n)
                pix_shift[0] <= 0;
            else
                pix_shift[0] <= pix_i;
    end
    genvar j;
    generate for(j = 1; j < DATA_WIDTH; j = j + 1)      begin
        always @(posedge clk or negedge rst_n)  begin
            if(!rst_n)
                pix_shift[j] <= 0;
            else
                pix_shift[j] <= pix_shift[j - 1];
        end
    end
    endgenerate
    assign pix_original = pix_shift[DATA_WIDTH - 1];
    assign pix_temp = z_temp[DATA_WIDTH - 1] >> DATA_WIDTH;

    //valid信号对齐
    always @(posedge clk or negedge rst_n)  begin
            if(!rst_n)
                valid_shift[0] <= 0;
            else
                valid_shift[0] <= valid_i;
    end
    genvar k;
    generate for(k = 1; k < DATA_WIDTH; k = k + 1)      begin
        always @(posedge clk or negedge rst_n)  begin
            if(!rst_n)
                valid_shift[k] <= 0;
            else
                valid_shift[k] <= valid_shift[k - 1];
        end
    end
    endgenerate
    assign valid_o = valid_shift[DATA_WIDTH - 1];

    //现在已经获取了去噪像素流以及与去噪像素流对齐的原像素流，用状态机进行mux处理
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)      begin
                state_r <= IDLE;
        end
        else begin
                state_r <= next_state_r;
        end
    end

    //行列计数以获取输出的行场同步，并供状态机使用
    always @(posedge clk or negedge rst_n)  begin
        if(!rst_n)
            column_cnt <= 0;
        else if(column_cnt == IMAGE_WIDTH - 1)
            column_cnt <= 0;
        else if(valid_o)
            column_cnt <= column_cnt + 1;
        else 
            column_cnt <= 0;
    end

    always @(posedge clk or negedge rst_n)  begin
        if(!rst_n)
            line_cnt <= 0;
        else if (column_cnt == IMAGE_WIDTH - 1)
            line_cnt <= line_cnt + 1;
        else if (line_cnt == IMAGE_HEIGHT - 1)
            line_cnt <= 0;
        else
            line_cnt <= line_cnt;
    end

    always @( *) begin
        case(state_r) 
                IDLE:           begin
                        if(valid_o)
                            next_state_r = FRONT;
                        else
                            next_state_r = IDLE;
                end
                FRONT:          begin
                        if((line_cnt == START_LINE - 1) & (column_cnt == IMAGE_WIDTH - 1))
                            next_state_r = NORMAL;
                        else
                            next_state_r = FRONT;
                end
                NORMAL:         begin
                        if((line_cnt == IMAGE_HEIGHT - START_LINE - 1) & (column_cnt == IMAGE_WIDTH - 1))
                            next_state_r = POST;
                        else
                            next_state_r = NORMAL;
                end
                POST:           begin
                        if((line_cnt == IMAGE_HEIGHT - 1) & (column_cnt == IMAGE_WIDTH - 1))
                            next_state_r = IDLE;
                        else
                            next_state_r = POST;
                end
        endcase
    end

    assign frame_sync_o = ((valid_o == 1) & (line_cnt == 0) & (column_cnt == 0)) ? 1 : 0;
    assign line_sync_o = ((valid_o == 1) & (column_cnt == 0)) ? 1 : 0;

    //按照当前状态，判断两个像素流如何进行mux
    always @( *) begin
        case(state_r) 
                IDLE:           begin
                    pix_denoise = pix_original;
                end
                FRONT:          begin
                    pix_denoise = pix_original;
                end
                NORMAL:         begin
                    if(((column_cnt >= 0) & (column_cnt < START_LINE)) | ((column_cnt >= IMAGE_WIDTH - START_LINE) & (column_cnt < IMAGE_WIDTH)))
                        pix_denoise = pix_original;
                    else
                        pix_denoise = pix_temp;
                end
                POST:           begin
                    pix_denoise = pix_original;
                end
        endcase
    end
    
endmodule