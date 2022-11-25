/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/1
 *   Version:    v1.0
 *   Note:       PE2
 *
 *********************************************************************/

module PE2 #(parameter  
                        DATA_WIDTH      =  12,
                        SRH_LENGTH      =  13
            )
            (
                weight_i        ,
                srh_bit_i       ,
                pix_sum_i       ,
                weight_sum_i    ,
                pix_sum_o       ,
                weight_sum_o    ,
                clk             ,
                rst_n
            );

    parameter   WEIGHT_WIDTH            =                   8                   ;
    parameter   WIN_SIZE                =    ((SRH_LENGTH + 1) / 2)**2          ;//49
    parameter   WEIGHT_SUM_WIDTH        =    WEIGHT_WIDTH + $clog2(WIN_SIZE)    ;//14
    parameter   PIX_SUM_WIDTH           =    WEIGHT_SUM_WIDTH + DATA_WIDTH      ;//26  

    input       [WEIGHT_WIDTH - 1           :0]             weight_i            ;
    input       [DATA_WIDTH - 1             :0]             srh_bit_i           ;
    input       [WEIGHT_SUM_WIDTH - 1       :0]             weight_sum_i        ;
    output      [WEIGHT_SUM_WIDTH - 1       :0]             weight_sum_o        ;
    input       [PIX_SUM_WIDTH - 1          :0]             pix_sum_i           ;
    output      [PIX_SUM_WIDTH - 1          :0]             pix_sum_o           ;
    input       clk                                                             ;
    input       rst_n                                                           ;

    reg         weight_sum_o                                                    ;
    reg         pix_sum_o                                                       ;

    always@(posedge clk or negedge rst_n)   begin
        if(!rst_n)
            weight_sum_o <= 0;
        else
            weight_sum_o <= weight_sum_i + weight_i;
    end

    always@(posedge clk or negedge rst_n)   begin
        if(!rst_n)
            pix_sum_o <= 0;
        else
            pix_sum_o <= pix_sum_i + weight_i * srh_bit_i;
    end 

endmodule