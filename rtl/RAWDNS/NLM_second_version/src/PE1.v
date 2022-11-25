/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/1
 *   Version:    v1.0
 *   Note:       PE1
 *
 *********************************************************************/
 
module PE1 #(parameter  
                        ROW_PE1         =   0,          //NOTE: For now, LENGTH should only be 4n+1
                        SRH_LENGTH      =   13,
                        REF_LENGTH      =   5,
                        TOTAL_LENGTH    =   17,
                        DATA_WIDTH      =   12,
                        SIGMA           =   20,
                        MIDDLE          =   0
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
                srh_bit_o           
            );

    parameter   WEIGHT_WIDTH            =                   8                                           ;
    parameter   KSIGMA                  =                   SIGMA * SIGMA                               ;
    parameter   SD_WIDTH                =                   2 * DATA_WIDTH + 2 * $clog2(REF_LENGTH)     ;//30
    parameter   EUR_WIDTH               =                   2 * DATA_WIDTH + 3 * $clog2(REF_LENGTH)     ;//33
    
    input       clk                                                                                     ;
    input       rst_n                                                                                   ;
    output      [DATA_WIDTH - 1                                 :0]                     srh_bit_o       ;
    input       [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_i     ;
    input       [SRH_LENGTH * DATA_WIDTH -1                     :0]                     srh_blk_i       ;
    input       [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_i       ;
    output      [WEIGHT_WIDTH - 1                               :0]                     weight_o        ;
    output      [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_o     ;
    output      [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk_o       ;
    output      [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_o       ;

    reg         srh_bit_o                                                                               ;
    reg         total_blk_o                                                                             ;
    reg         srh_blk_o                                                                               ;
    reg         ref_blk_o                                                                               ;

    reg         [SD_WIDTH * REF_LENGTH - 1                                      :0]                     SD_r                        ;//5*30BIT
    reg         [SD_WIDTH - 1                                                   :0]                     ACCU    [REF_LENGTH - 1:0]  ;//30BIT
    wire        [REF_LENGTH * DATA_WIDTH - 1                                    :0]                     total_blk_r                 ;
    wire        [EUR_WIDTH - 1                                                  :0]                     ACC_p   [REF_LENGTH - 1:0]  ;//33BIT
    wire        [EUR_WIDTH - 1                                                  :0]                     G_Eur                       ;//33BIT
    reg         [WEIGHT_WIDTH - 1                                               :0]                     weight_r                    ;
    //According to ROW_PE1, fetch the elements to be used
    assign   total_blk_r = total_blk_i[(2 * ROW_PE1 + REF_LENGTH) * DATA_WIDTH - 1 : 2 * ROW_PE1 * DATA_WIDTH];
           
    //Parallel Squared Diffenence Process
    genvar i;
    generate for(i = 0; i < REF_LENGTH; i = i + 1)      begin
        always@(posedge clk or negedge rst_n)       begin
            if(!rst_n)
                SD_r[(SD_WIDTH * i + SD_WIDTH - 1)-:SD_WIDTH] <= 0;
            else 
                SD_r[(SD_WIDTH * i + SD_WIDTH - 1)-:SD_WIDTH] <= (total_blk_r[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH] > ref_blk_i[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH]) ? 
                (total_blk_r[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH] - ref_blk_i[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH]) * (total_blk_r[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH] - ref_blk_i[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH])
                : (ref_blk_i[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH] - total_blk_r[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH]) * (ref_blk_i[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH] - total_blk_r[(DATA_WIDTH * i + DATA_WIDTH - 1)-:DATA_WIDTH]);
        end
    end
    endgenerate

    //Pipelined Accumulate eur_distance
    AdderTree #(.DATA_WIDTH(SD_WIDTH),
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
        AdderTree #(.DATA_WIDTH(SD_WIDTH),
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
    assign  G_Eur = ACCU[REF_LENGTH - 1] + (ACCU[REF_LENGTH - 1] << 2);

    //exp LUT
    always@(*)       begin
        if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 10)
            weight_r = 255;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 11)
            weight_r = 251;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 12)
            weight_r = 236;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 13)
            weight_r = 201;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 14)
            weight_r = 163;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 15)
            weight_r = 125;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 16)
            weight_r = 93;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 17)
            weight_r = 67;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 18)
            weight_r = 47;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 19)
            weight_r = 33;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 20)
            weight_r = 22;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 21)
            weight_r = 15;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 22)
            weight_r = 10;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 23)
            weight_r = 7;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 24)
            weight_r = 5;
        else if(G_Eur <= REF_LENGTH * REF_LENGTH * KSIGMA * 25)
            weight_r = 3;
        else
            weight_r = 0;   
    end
    
    assign weight_o = (MIDDLE == 1) ? 0 : weight_r;

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
            srh_bit_o <= srh_blk_i[DATA_WIDTH * 2 * ROW_PE1 + DATA_WIDTH - 1 : DATA_WIDTH * 2 * ROW_PE1];
    end

endmodule