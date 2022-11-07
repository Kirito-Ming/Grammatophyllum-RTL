/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/1
 *   Version:    v1.0
 *   Note:       PE1
 *
 *********************************************************************/
 
module PE1 #(parameter  
                        ROW_PE1         =   0,
                        SRH_LENGTH      =   7,
                        REF_LENGTH      =   5,
                        TOTAL_LENGTH    =   11,
                        DATA_WIDTH      =   16,
                        SIGMA           =   20,
                        FILTERPARA      =   102
            )
            (
                clk                 ,
                rst_n               ,
                total_blk_i         ,
                srh_blk_i           ,
                ref_blk_i           ,
                weight_o            ,
                total_blk_o         ,
                srh_blk_o           ,
                ref_blk_o           ,
                srh_bit_o           ,
            );

    parameter   WEIGHT_WIDTH            =                   8                  ;//todo
    parameter   KSIGMA2                 =                   (SIGMA * SIGMA * FILTERPARA * FILTERPARA) >> 8;

    input       clk                     ;
    input       rst_n                   ;
    output      [DATA_WIDTH - 1                                 :0]                     srh_bit_o       ;
    input       [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_i     ;
    input       [SRH_LENGTH * DATA_WIDTH -1                     :0]                     srh_blk_i       ;
    input       [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_i       ;
    output      [WEIGHT_WIDTH - 1                               :0]                     weight_o        ;
    output      [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_o     ;
    output      [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk_o       ;
    output      [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_o       ;

    reg         weight_o                                                                                ;
    reg         srh_bit_o                                                                               ;
    reg         total_blk_o                                                                             ;
    reg         srh_blk_o                                                                               ;
    reg         ref_blk_o                                                                               ;

    reg         [(2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)) * REF_LENGTH - 1     :0]                     SD_r                        ;
    reg         [2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)- 1                     :0]                     ACCU    [REF_LENGTH - 1:0]  ;
    wire        [REF_LENGTH * DATA_WIDTH - 1                                    :0]                     total_blk_r                 ;
    wire        [2 * DATA_WIDTH + 3 * $clog2(REF_LENGTH)- 1                     :0]                     ACC_p   [REF_LENGTH - 1:0]  ;
    wire        [2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)- 1                     :0]                     G_Eur                       ;

    //According to ROW_PE1, fetch the elements to be used
    assign   total_blk_r = total_blk_i[(ROW_PE1 + REF_LENGTH) * DATA_WIDTH - 1 : ROW_PE1 * DATA_WIDTH];
           
    //Parallel Squared Diffenence Process
    genvar i;
    generate for(i = 0; i < REF_LENGTH; i = i + 1)      begin
        always@(posedge clk or negedge rst_n)       begin
            if(!rst_n)
                SD_r[((2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)) * i + (2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)) - 1)-:(2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH))] <= 0;
            else 
                SD_r[((2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)) * i + (2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)) - 1)-:(2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH))] <= (total_blk_r[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH] - ref_blk_i[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH]) * (total_blk_r[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH] - ref_blk_i[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH]);
        end
    end
    endgenerate

    //Pipeline Accumulate eur_distance
    AdderTree #(.DATA_WIDTH(2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)),
                .LENGTH(REF_LENGTH))
            u_AdderTree(
            .in_addends(SD_r),
            .out_sum(ACC_p[0])
        );
    always@(posedge clk or negedge rst_n)       begin
        if(!rst_n)
            ACCU[0] <= 0;
        else
            ACCU[0] <= ACC_p[0];
    end

    genvar j;
    generate for(j = 1; j < REF_LENGTH; j = j + 1)      begin
        AdderTree #(.DATA_WIDTH(2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)),
                .LENGTH(REF_LENGTH + 1))
            u_AdderTree(
            .in_addends({ACCU[j - 1],SD_r}),
            .out_sum(ACC_p[j])
        );
        always@(posedge clk or negedge rst_n)       begin
            if(!rst_n)
                ACCU[j] <= 0;
            else
                ACCU[j] <= ACC_p[j];
        end
    end 
    endgenerate
    
    //Gauss weighted eur_distance
    
    assign  G_Eur = (ACCU[REF_LENGTH - 1] > 2 * SIGMA * SIGMA) ? (ACCU[REF_LENGTH - 1] - 2 * SIGMA * SIGMA) : 0;

    //exp LUT
    always@(*)       begin
        if(KSIGMA2 == 0)
            weight_o = 0;
        else if((G_Eur <= KSIGMA2) && (10 * G_Eur > 9 * KSIGMA2))
            weight_o = 99;
        else if((10 * G_Eur <= 9 * KSIGMA2) && (10 * G_Eur > 8 * KSIGMA2))
            weight_o = 111;
        else if((10 * G_Eur <= 8 * KSIGMA2) && (10 * G_Eur > 7 * KSIGMA2))
            weight_o = 120;
        else if((10 * G_Eur <= 7 * KSIGMA2) && (10 * G_Eur > 6 * KSIGMA2))
            weight_o = 133;
        else if((10 * G_Eur <= 6 * KSIGMA2) && (10 * G_Eur > 5 * KSIGMA2))
            weight_o = 148;
        else if((10 * G_Eur <= 5 * KSIGMA2) && (10 * G_Eur > 4 * KSIGMA2))
            weight_o = 163;
        else if((10 * G_Eur <= 4 * KSIGMA2) && (10 * G_Eur > 3 * KSIGMA2))
            weight_o = 180;
        else if((10 * G_Eur <= 3 * KSIGMA2) && (10 * G_Eur > 2 * KSIGMA2))
            weight_o = 197;
        else if((10 * G_Eur <= 2 * KSIGMA2) && (10 * G_Eur > 1 * KSIGMA2))
            weight_o = 220;
        else if(10 * G_Eur <= KSIGMA2)
            weight_o = 244;
        else if((G_Eur > KSIGMA2) && (5 * G_Eur < 6 * KSIGMA2))
            weight_o = 85;
        else if((5 * G_Eur >= 6 * KSIGMA2) && (5 * G_Eur < 7 * KSIGMA2))
            weight_o = 70; 
        else if((5 * G_Eur >= 7 * KSIGMA2) && (5 * G_Eur < 8 * KSIGMA2))
            weight_o = 57; 
        else if((5 * G_Eur >= 8 * KSIGMA2) && (5 * G_Eur < 9 * KSIGMA2))
            weight_o = 47; 
        else if((5 * G_Eur >= 9 * KSIGMA2) && (5 * G_Eur < 10 * KSIGMA2))
            weight_o = 39; 
        else if((5 * G_Eur >= 10 * KSIGMA2) && (5 * G_Eur < 11 * KSIGMA2))
            weight_o = 32; 
        else if((5 * G_Eur >= 11 * KSIGMA2) && (5 * G_Eur < 12 * KSIGMA2))
            weight_o = 26; 
        else if((5 * G_Eur >= 12 * KSIGMA2) && (5 * G_Eur < 13 * KSIGMA2))
            weight_o = 21; 
        else if((5 * G_Eur >= 13 * KSIGMA2) && (5 * G_Eur < 14 * KSIGMA2))
            weight_o = 18; 
        else if((5 * G_Eur >= 14 * KSIGMA2) && (5 * G_Eur < 15 * KSIGMA2))
            weight_o = 15; 
        else if((5 * G_Eur >= 15 * KSIGMA2) && (5 * G_Eur < 16 * KSIGMA2))
            weight_o = 12; 
        else if((5 * G_Eur >= 16 * KSIGMA2) && (5 * G_Eur < 17 * KSIGMA2))
            weight_o = 10; 
        else if((5 * G_Eur >= 17 * KSIGMA2) && (5 * G_Eur < 18 * KSIGMA2))
            weight_o = 8; 
        else if((5 * G_Eur >= 18 * KSIGMA2) && (5 * G_Eur < 19 * KSIGMA2))
            weight_o = 7; 
        else if((5 * G_Eur >= 19 * KSIGMA2) && (5 * G_Eur < 20 * KSIGMA2))
            weight_o = 6; 
        else if((5 * G_Eur >= 20 * KSIGMA2) && (5 * G_Eur < 21 * KSIGMA2))
            weight_o = 3; 
        else if((5 * G_Eur >= 21 * KSIGMA2) && (5 * G_Eur < 22 * KSIGMA2))
            weight_o = 1; 
        else
            weight_o = 0;   
    end

    //Pass blk data
    always@(posedge clk or negedge rst_n)       begin
        if(!rst_n)
            srh_blk_o <= 0;
        else
            srh_blk_o <= srh_blk_i;
    end

    always@(posedge clk or negedge rst_n)       begin
        if(!rst_n)
            total_blk_o <= 0;
        else
            total_blk_o <= total_blk_i;
    end

    always@(posedge clk or negedge rst_n)       begin
        if(!rst_n)
            ref_blk_o <= 0;
        else
            ref_blk_o <= ref_blk_i;
    end

    always@(posedge clk or negedge rst_n)       begin
        if(!rst_n)
            srh_bit_o <= 0;
        else
            srh_bit_o <= srh_blk_i[DATA_WIDTH * ROW_PE1 + DATA_WIDTH - 1 : DATA_WIDTH * ROW_PE1];
    end

endmodule