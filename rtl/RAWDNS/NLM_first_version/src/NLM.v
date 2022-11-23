/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/19
 *   Version:    v1.0
 *   Note:       NLM
 *
 *********************************************************************/

module NLM #(parameter                  BLOCK_RADIUS        =       2,
                                        WIN_RADIUS          =       6,
                                        ADDR_WIDTH          =       12,
                                        IMAGE_WIDTH         =       1920,
                                        IMAGE_HEIGHT        =       1080,
                                        SRH_LENGTH          =       13,
                                        REF_LENGTH          =       5,
                                        TOTAL_LENGTH        =       17,
                                        DATA_WIDTH          =       12,
                                        SIGMA               =       160)
            (
                    clk,
                    rst_n,
                    valid_i,
                    en_i,
                    pix_i,
                    frame_sync_i,
                    line_sync_i,
                    pix_original,
                    pix_denoise,
                    frame_sync_o,
                    line_sync_o,
                    valid_o
            );

        parameter       SRAM_SIZE               =                   2 * (BLOCK_RADIUS + WIN_RADIUS + 1)                                         ;//18 SRAM
        parameter       START_CAL               =                   SRAM_SIZE - 1                                                               ;//17 start to process  
        parameter       WEIGHT_WIDTH            =                   8                                                                           ;
        parameter       WIN_SIZE                =                   ((SRH_LENGTH + 1) / 2)**2                                                   ;//49
        parameter       WEIGHT_SUM_WIDTH        =                   WEIGHT_WIDTH + $clog2(WIN_SIZE)                                             ;//14
        parameter       PIX_SUM_WIDTH           =                   WEIGHT_SUM_WIDTH + DATA_WIDTH                                               ;//26  
        parameter       DELAY                   =                   WIN_SIZE + REF_LENGTH - BLOCK_RADIUS - WIN_RADIUS - 1                       ; 

        input                                                                                   en_i                                            ;
        input                                                                                   valid_i                                         ;
        input                                                                                   frame_sync_i                                    ;
        input                                                                                   line_sync_i                                     ;
        input                                                                                   clk                                             ;
        input           [DATA_WIDTH - 1                                 :0]                     pix_i                                           ;
        input                                                                                   rst_n                                           ;
        output                                                                                  valid_o                                         ;
        output                                                                                  line_sync_o                                     ;
        output                                                                                  frame_sync_o                                    ;
        output          [DATA_WIDTH - 1                                 :0]                     pix_original                                    ;
        output          [DATA_WIDTH - 1                                 :0]                     pix_denoise                                     ;

        wire            [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk                                       ;
        wire            [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk                                         ;
        wire            [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk                                         ;
        wire            [DATA_WIDTH - 1                                 :0]                     img_pix                                         ;
        reg             [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk_r      [REF_LENGTH - 1 : 0]             ;
        reg             [DATA_WIDTH - 1                                 :0]                     pix_r                                           ;
        reg             [DATA_WIDTH - 1                                 :0]                     pix_delay      [DELAY - 1 : 0]                  ;
        reg                                                                                     valid_delay    [DELAY - 1 : 0]                  ;
        wire                                                                                    valid_r                                         ;
        wire            [WEIGHT_SUM_WIDTH - 1                           :0]                     weight_sum                                      ;
        wire            [PIX_SUM_WIDTH - 1                              :0]                     pix_sum                                         ;

        always @(posedge clk or negedge rst_n)          begin
                if(!rst_n)
                        pix_r <= 0;
                else
                        pix_r <= pix_i;
        end

        //Sram外围电路
        Sram_outer #(           .BLOCK_RADIUS(BLOCK_RADIUS),
                                .WIN_RADIUS(WIN_RADIUS),
                                .ADDR_WIDTH(ADDR_WIDTH),
                                .IMAGE_HEIGHT(IMAGE_HEIGHT),
                                .IMAGE_WIDTH(IMAGE_WIDTH),
                                .DATA_WIDTH(DATA_WIDTH))
        u_Sram_outer(
                .clk(clk),
                .rst_n(rst_n),
                .valid_i(valid_i),
                .en_i(en_i),
                .pix_i(pix_r),
                .frame_sync_i(frame_sync_i),
                .line_sync_i(line_sync_i),
                .total_blk_o(total_blk),
                .ref_blk_o(ref_blk),
                .srh_blk_o(srh_blk),
                .valid_o(valid_r),
                .img_pix_o(img_pix)
        );

        //为了对齐权重和搜索窗口像素点，需要对srh_blk进行延时
        always @(posedge clk or negedge rst_n)          begin
                if(!rst_n)
                        srh_blk_r[0] <= 0;
                else
                        srh_blk_r[0] <= srh_blk;
        end
        genvar i;
        generate for(i = 1; i < REF_LENGTH; i = i + 1)          begin
                always @(posedge clk or negedge rst_n)          begin
                        if(!rst_n)
                                srh_blk_r[i] <= 0;
                        else
                                srh_blk_r[i] <= srh_blk_r[i - 1];
                end
        end
        endgenerate

        //脉动阵列
        SA #(                   .SRH_LENGTH(SRH_LENGTH),
                                .REF_LENGTH(REF_LENGTH),
                                .TOTAL_LENGTH(TOTAL_LENGTH),
                                .DATA_WIDTH(DATA_WIDTH),
                                .SIGMA(SIGMA))
        u_SA(
                .clk(clk),
                .rst_n(rst_n),
                .total_blk_i(total_blk),
                .ref_blk_i(ref_blk),
                .srh_blk_i(srh_blk_r[REF_LENGTH - 1]),
                .pix_sum_o(pix_sum),
                .weight_sum_o(weight_sum)
        );

        //对齐原像素、权重和、像素权重和
        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)
                        pix_delay[0] <= 0;
                else
                        pix_delay[0] <= img_pix;        
        end
        genvar j;
        generate for(j = 1; j < DELAY; j = j + 1)       begin
                always @(posedge clk or negedge rst_n)  begin
                        if(!rst_n)
                                pix_delay[j] <= 0;
                        else 
                                pix_delay[j] <= pix_delay[j - 1];
                end
        end
        endgenerate

        //valid信号也跟着像素流做延时，valid_delay[DELAY - 1]、pix_delay[DELAY - 1]、weight_sum、pix_sum作为最后output模块的输入
        always @(posedge clk or negedge rst_n)  begin
                if(!rst_n)
                        valid_delay[0] <= 0;
                else
                        valid_delay[0] <= valid_r;        
        end
        genvar k;
        generate for(k = 1; k < DELAY; k = k + 1)       begin
                always @(posedge clk or negedge rst_n)  begin
                        if(!rst_n)
                                valid_delay[k] <= 0;
                        else 
                                valid_delay[k] <= valid_delay[k - 1];
                end
        end
        endgenerate

        //最终输出处理模块
        output_ctrl #(          .SUM_WIDTH(PIX_SUM_WIDTH),
                                .DATA_WIDTH(DATA_WIDTH),
                                .IMAGE_HEIGHT(IMAGE_HEIGHT),
                                .IMAGE_WIDTH(IMAGE_WIDTH),
                                .BLOCK_RADIUS(BLOCK_RADIUS),
                                .WIN_RADIUS(WIN_RADIUS)
        )
        u_output_ctrl(
                .clk(clk),
                .valid_i(valid_delay[DELAY - 1]),
                .rst_n(rst_n),
                .pix_sum_i(pix_sum),
                .weight_sum_i(weight_sum),
                .pix_i(pix_delay[DELAY - 1]),
                .pix_original(pix_original),
                .pix_denoise(pix_denoise),
                .valid_o(valid_o),
                .line_sync_o(line_sync_o),
                .frame_sync_o(frame_sync_o)
        );

        endmodule