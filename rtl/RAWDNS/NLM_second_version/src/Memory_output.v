/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/12
 *   Version:    v1.0
 *   Note:       Memory_output
 *
 *********************************************************************/

module Memory_output #(parameter    ADDR_WIDTH      =  12,
                                    SRH_LENGTH      =  13,
                                    REF_LENGTH      =  5,
                                    TOTAL_LENGTH    =  17,
                                    DATA_WIDTH      =  12,
                                    BLOCK_RADIUS    =  2,
                                    WIN_RADIUS      =  6)
            (
                clk,
                rst_n,
                data_i,
                head_num_i,
                total_blk_o,
                ref_blk_o,
                srh_blk_o,
                img_pix_o           
            );

    parameter   MEM_DEPTH               =       2 ** ADDR_WIDTH                                                 ;
    parameter   SRAM_SIZE               =       2 * (BLOCK_RADIUS + WIN_RADIUS + 1)                             ;//18
    parameter   HALF                    =       SRAM_SIZE / 2                                                   ;
    parameter   REG_NUM                 =       (TOTAL_LENGTH - REF_LENGTH) / 2 + 1                             ;//7
    parameter   TOTAL_SRH               =       (TOTAL_LENGTH - SRH_LENGTH) / 2                                 ;//2
    parameter   TOTAL_REF               =       (TOTAL_LENGTH - REF_LENGTH) / 2                                 ;//6
    parameter   SRH_REF                 =       (SRH_LENGTH - REF_LENGTH) / 2                                   ;//4

    input                                                                               clk                     ;
    input                                                                               rst_n                   ;
    input       [SRAM_SIZE * DATA_WIDTH - 1                     :0]                     data_i                  ;
    input       [4                                              :0]                     head_num_i              ;
    output      [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_o             ;
    output      [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_o               ;
    output      [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk_o               ;
    output      [DATA_WIDTH - 1                                 :0]                     img_pix_o               ;

    wire        [(SRAM_SIZE - 1) * DATA_WIDTH - 1               :0]                     data_valid                                      ;// 0 - 17 head - tail
    reg         [(SRAM_SIZE - 1) * DATA_WIDTH - 1               :0]                     data_delay              [REG_NUM - 1 : 0]       ;
    reg         [4                                              :0]                     head_num_r                                      ;

    always @(posedge clk or negedge rst_n)      begin
        if(!rst_n)
            head_num_r <= 0;
        else
            head_num_r <= head_num_i;
    end

    //get valid data
    genvar i;
    generate for(i = 0; i < SRAM_SIZE - 1; i = i + 1)   begin
        assign data_valid[(i + 1) * DATA_WIDTH - 1:i * DATA_WIDTH] = ((head_num_r + i < 18) ? data_i[((head_num_r + i + 1) * DATA_WIDTH - 1)-:DATA_WIDTH] : data_i[((head_num_r + i - 17) * DATA_WIDTH - 1)-:DATA_WIDTH]);
    end
    endgenerate

    //shift register
    always @(posedge clk or negedge rst_n)  begin
            if(!rst_n)
                data_delay[0] <= 0;
            else
                data_delay[0] <= data_valid;
    end
    genvar k;
    generate for(k = 1; k < REG_NUM; k = k + 1)   begin
        always @(posedge clk or negedge rst_n)  begin
            if(!rst_n)
                data_delay[k] <= 0;
            else
                data_delay[k] <= data_delay[k - 1];
        end
    end
    endgenerate

    //output
    assign total_blk_o = data_delay[REG_NUM - 1];
    assign ref_blk_o = data_delay[0][(TOTAL_LENGTH - TOTAL_REF) * DATA_WIDTH - 1 : TOTAL_REF * DATA_WIDTH];
    assign srh_blk_o = data_delay[SRH_REF][(TOTAL_LENGTH - TOTAL_SRH) * DATA_WIDTH - 1 : TOTAL_SRH * DATA_WIDTH];
    assign img_pix_o = data_delay[REG_NUM - 1][HALF * DATA_WIDTH - 1 : (HALF - 1) * DATA_WIDTH];
    
endmodule