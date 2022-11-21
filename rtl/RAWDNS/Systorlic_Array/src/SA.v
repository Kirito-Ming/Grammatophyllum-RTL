/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/14
 *   Version:    v1.0
 *   Note:       SA
 *
 *********************************************************************/
 
module SA #(parameter  
                        SRH_LENGTH      =   13,
                        REF_LENGTH      =   5,
                        TOTAL_LENGTH    =   17,
                        DATA_WIDTH      =   12,
                        SIGMA           =   20
            )
            (
                clk                 ,
                rst_n               ,
                total_blk_i         ,
                srh_blk_i           ,//delayed REF_LENGTH periods
                ref_blk_i           ,
                pix_sum_o           ,
                weight_sum_o    
            );

    parameter   WEIGHT_WIDTH            =                   8                                               ;
    parameter   WIN_SIZE                =                   ((SRH_LENGTH + 1) / 2)**2                       ;//49
    parameter   WEIGHT_SUM_WIDTH        =                   WEIGHT_WIDTH + $clog2(WIN_SIZE)                 ;//14
    parameter   PIX_SUM_WIDTH           =                   WEIGHT_SUM_WIDTH + DATA_WIDTH                   ;//26
    parameter   KSIGMA                  =                   SIGMA * SIGMA                                   ;
    parameter   CAL_SRH_LENGTH          =                   (SRH_LENGTH + 1) / 2                            ;//7
    parameter   MIDDLE_POS              =                   (CAL_SRH_LENGTH + 1) / 2                        ;//4

    input       clk                                                                                         ;
    input       rst_n                                                                                       ;
    input       [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_i         ;
    input       [SRH_LENGTH * DATA_WIDTH -1                     :0]                     srh_blk_i           ;
    input       [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_i           ;
    output      [WEIGHT_SUM_WIDTH - 1                           :0]                     weight_sum_o        ;
    output      [PIX_SUM_WIDTH - 1                              :0]                     pix_sum_o           ;

    wire        [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_o     [CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1    :0]    ;
    wire        [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_o       [CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1    :0]    ;
    wire        [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk_o       [CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1    :0]    ;
    wire        [WEIGHT_SUM_WIDTH - 1                           :0]                     weight_sum      [CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1    :0]    ;
    wire        [PIX_SUM_WIDTH - 1                              :0]                     pix_sum         [CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1    :0]    ;

    //First PE
    PE #(   .ROW_PE(0),
            .SRH_LENGTH(SRH_LENGTH),
            .REF_LENGTH(REF_LENGTH),
            .TOTAL_LENGTH(TOTAL_LENGTH),
            .DATA_WIDTH(DATA_WIDTH),
            .SIGMA(SIGMA)
        )
    u_PEF(
        .clk(clk),
        .rst_n(rst_n),
        .total_blk_i(total_blk_i),
        .srh_blk_i(srh_blk_i),
        .ref_blk_i(ref_blk_i),
        .total_blk_o(total_blk_o[0]),
        .srh_blk_o(srh_blk_o[0]),
        .ref_blk_o(ref_blk_o[0]),
        .pix_sum_i(0),
        .weight_sum_i(0),
        .pix_sum_o(pix_sum[0]),
        .weight_sum_o(weight_sum[0])
    );

    //PE line 1
    genvar i;
    generate for(i = 1; i < CAL_SRH_LENGTH; i = i + 1) begin
        PE #(   .ROW_PE(0),
                .SRH_LENGTH(SRH_LENGTH),
                .REF_LENGTH(REF_LENGTH),
                .TOTAL_LENGTH(TOTAL_LENGTH),
                .DATA_WIDTH(DATA_WIDTH),
                .SIGMA(SIGMA)
            )
        u_PEL1(
            .clk(clk),
            .rst_n(rst_n),
            .total_blk_i(total_blk_o[i * CAL_SRH_LENGTH - 3]),
            .srh_blk_i(srh_blk_o[i * CAL_SRH_LENGTH - 3]),
            .ref_blk_i(ref_blk_o[i * CAL_SRH_LENGTH - 1]),
            .total_blk_o(total_blk_o[i * CAL_SRH_LENGTH]),
            .srh_blk_o(srh_blk_o[i * CAL_SRH_LENGTH]),
            .ref_blk_o(ref_blk_o[i * CAL_SRH_LENGTH]),
            .pix_sum_i(pix_sum[i * CAL_SRH_LENGTH - 1]),
            .weight_sum_i(weight_sum[i * CAL_SRH_LENGTH - 1]),
            .pix_sum_o(pix_sum[i * CAL_SRH_LENGTH]),
            .weight_sum_o(weight_sum[i * CAL_SRH_LENGTH])
        );
    end
    endgenerate

    //PE middle line
    genvar j1,j2;
    generate for(j1 = 2; j1 < CAL_SRH_LENGTH; j1 = j1 + 1)  begin
        for(j2 = 0; j2 < CAL_SRH_LENGTH; j2 = j2 + 1)    begin
            if((j1 != MIDDLE_POS) | (j2 != MIDDLE_POS - 1))   begin
                PE #(   .ROW_PE(j1 - 1),
                        .SRH_LENGTH(SRH_LENGTH),
                        .REF_LENGTH(REF_LENGTH),
                        .TOTAL_LENGTH(TOTAL_LENGTH),
                        .DATA_WIDTH(DATA_WIDTH),
                        .SIGMA(SIGMA)
                )
                u_PEML(
                    .clk(clk),
                    .rst_n(rst_n),
                    .total_blk_i(total_blk_o[(j1 - 1) + j2 * CAL_SRH_LENGTH - 1]),
                    .srh_blk_i(srh_blk_o[(j1 - 1) + j2 * CAL_SRH_LENGTH - 1]),
                    .ref_blk_i(ref_blk_o[(j1 - 1) + j2 * CAL_SRH_LENGTH - 1]),
                    .total_blk_o(total_blk_o[(j1 - 1) + j2 * CAL_SRH_LENGTH]),
                    .srh_blk_o(srh_blk_o[(j1 - 1) + j2 * CAL_SRH_LENGTH]),
                    .ref_blk_o(ref_blk_o[(j1 - 1) + j2 * CAL_SRH_LENGTH]),
                    .pix_sum_i(pix_sum[(j1 - 1) + j2 * CAL_SRH_LENGTH - 1]),
                    .weight_sum_i(weight_sum[(j1 - 1) + j2 * CAL_SRH_LENGTH - 1]),
                    .pix_sum_o(pix_sum[(j1 - 1) + j2 * CAL_SRH_LENGTH]),
                    .weight_sum_o(weight_sum[(j1 - 1) + j2 * CAL_SRH_LENGTH])
                );
            end
        end
    end
    endgenerate

    //PE middle
    PE #(   .ROW_PE(MIDDLE_POS - 1),
            .SRH_LENGTH(SRH_LENGTH),
            .REF_LENGTH(REF_LENGTH),
            .TOTAL_LENGTH(TOTAL_LENGTH),
            .DATA_WIDTH(DATA_WIDTH),
            .SIGMA(SIGMA),
            .MIDDLE(1)
        )
    u_PEM(
        .clk(clk),
        .rst_n(rst_n),
        .total_blk_i(total_blk_o[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH - 1]),
        .srh_blk_i(srh_blk_o[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH - 1]),
        .ref_blk_i(ref_blk_o[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH - 1]),
        .total_blk_o(total_blk_o[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH]),
        .srh_blk_o(srh_blk_o[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH]),
        .ref_blk_o(ref_blk_o[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH]),
        .pix_sum_i(pix_sum[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH - 1]),
        .weight_sum_i(weight_sum[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH - 1]),
        .pix_sum_o(pix_sum[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH]),
        .weight_sum_o(weight_sum[(MIDDLE_POS - 1) + (MIDDLE_POS - 1) * CAL_SRH_LENGTH])
    );

    //PE last line
    genvar k;
    generate for(k = 1; k < CAL_SRH_LENGTH; k = k + 1)  begin
        PE #(   .ROW_PE(CAL_SRH_LENGTH - 1),
                .SRH_LENGTH(SRH_LENGTH),
                .REF_LENGTH(REF_LENGTH),
                .TOTAL_LENGTH(TOTAL_LENGTH),
                .DATA_WIDTH(DATA_WIDTH),
                .SIGMA(SIGMA)
        )
        u_PELL(
            .clk(clk),
            .rst_n(rst_n),
            .total_blk_i(total_blk_o[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 2]),
            .srh_blk_i(srh_blk_o[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 2]),
            .ref_blk_i(ref_blk_o[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 2]),
            .total_blk_o(total_blk_o[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 1]),
            .srh_blk_o(srh_blk_o[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 1]),
            .ref_blk_o(ref_blk_o[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 1]),
            .pix_sum_i(pix_sum[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 2]),
            .weight_sum_i(weight_sum[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 2]),
            .pix_sum_o(pix_sum[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 1]),
            .weight_sum_o(weight_sum[(k - 1) * CAL_SRH_LENGTH + CAL_SRH_LENGTH - 1])
        );
    end
    endgenerate

    //Last PE
    PE #(   .ROW_PE(CAL_SRH_LENGTH - 1),
            .SRH_LENGTH(SRH_LENGTH),
            .REF_LENGTH(REF_LENGTH),
            .TOTAL_LENGTH(TOTAL_LENGTH),
            .DATA_WIDTH(DATA_WIDTH),
            .SIGMA(SIGMA)
        )
    u_PEL(
        .clk(clk),
        .rst_n(rst_n),
        .total_blk_i(total_blk_o[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 2]),
        .srh_blk_i(srh_blk_o[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 2]),
        .ref_blk_i(ref_blk_o[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 2]),
        .total_blk_o(total_blk_o[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1]),
        .srh_blk_o(srh_blk_o[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1]),
        .ref_blk_o(ref_blk_o[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 1]),
        .pix_sum_i(pix_sum[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 2]),
        .weight_sum_i(weight_sum[CAL_SRH_LENGTH * CAL_SRH_LENGTH - 2]),
        .pix_sum_o(pix_sum_o),
        .weight_sum_o(weight_sum_o)
    );
endmodule