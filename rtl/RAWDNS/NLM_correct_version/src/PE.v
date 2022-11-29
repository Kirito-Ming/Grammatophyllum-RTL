/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/1
 *   Version:    v1.0
 *   Note:       PE
 *
 *********************************************************************/
 
module PE #(parameter  
                        ROW_PE          =   0,
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
                srh_blk_i           ,//delayed REF_LENGTH periods
                ref_blk_i           ,
                total_blk_o         ,
                srh_blk_o           ,
                ref_blk_o           ,
                pix_sum_i           ,
                weight_sum_i        ,
                pix_sum_o           ,
                weight_sum_o    
            );
    parameter   WEIGHT_WIDTH            =                   8                                               ;
    parameter   WIN_SIZE                =                   ((SRH_LENGTH + 1) / 2)**2                       ;//49
    parameter   WEIGHT_SUM_WIDTH        =                   WEIGHT_WIDTH + $clog2(WIN_SIZE)                 ;//14
    parameter   PIX_SUM_WIDTH           =                   WEIGHT_SUM_WIDTH + DATA_WIDTH                   ;//26
    parameter   KSIGMA                  =                   SIGMA * SIGMA                                   ;

    input       clk                                                                                         ;
    input       rst_n                                                                                       ;
    input       [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_i         ;
    input       [SRH_LENGTH * DATA_WIDTH -1                     :0]                     srh_blk_i           ;
    input       [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_i           ;
    output      [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_o         ;
    output      [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk_o           ;
    output      [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_o           ;
    input       [WEIGHT_SUM_WIDTH - 1                           :0]                     weight_sum_i        ;
    output      [WEIGHT_SUM_WIDTH - 1                           :0]                     weight_sum_o        ;
    input       [PIX_SUM_WIDTH - 1                              :0]                     pix_sum_i           ;
    output      [PIX_SUM_WIDTH - 1                              :0]                     pix_sum_o           ;

    wire         [DATA_WIDTH - 1                                 :0]                     srh_bit_o           ;
    wire         [WEIGHT_WIDTH - 1                               :0]                     weight_o            ;

    PE1 #(      .ROW_PE1(ROW_PE),
                .SRH_LENGTH(SRH_LENGTH),
                .REF_LENGTH(REF_LENGTH),
                .TOTAL_LENGTH(TOTAL_LENGTH),
                .DATA_WIDTH(DATA_WIDTH),
                .SIGMA(SIGMA),
                .MIDDLE(MIDDLE))
    u_PE1(
        .clk(clk),
        .rst_n(rst_n),
        .total_blk_i(total_blk_i),
        .ref_blk_i(ref_blk_i),
        .srh_blk_i(srh_blk_i),
        .weight_o(weight_o),
        .total_blk_o(total_blk_o),
        .ref_blk_o(ref_blk_o),
        .srh_blk_o(srh_blk_o),
        .srh_bit_o(srh_bit_o)
    );

    PE2 #(      .DATA_WIDTH(DATA_WIDTH),
                .SRH_LENGTH(SRH_LENGTH))
    u_PE2(
        .clk(clk),
        .rst_n(rst_n),
        .weight_i(weight_o),
        .srh_bit_i(srh_bit_o),
        .pix_sum_i(pix_sum_i),
        .pix_sum_o(pix_sum_o),
        .weight_sum_i(weight_sum_i),
        .weight_sum_o(weight_sum_o)
    );
    
endmodule