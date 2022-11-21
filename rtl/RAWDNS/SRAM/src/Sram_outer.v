/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/19
 *   Version:    v1.0
 *   Note:       Sram_controller
 *
 *********************************************************************/

module Sram_outer #(parameter           BLOCK_RADIUS        =       2,
                                        WIN_RADIUS          =       6,
                                        ADDR_WIDTH          =       12,
                                        IMAGE_WIDTH         =       432,
                                        IMAGE_HEIGHT        =       264,
                                        DATA_WIDTH          =       12)
            (
                    clk,
                    rst_n,
                    valid_i,
                    en_i,
                    pix_i,
                    frame_sync_i,
                    line_sync_i,
                    total_blk_o,
                    ref_blk_o,
                    srh_blk_o
            );

        parameter SRAM_SIZE             =       2 * (BLOCK_RADIUS + WIN_RADIUS + 1)                                     ;//18 SRAM
        parameter START_CAL             =       SRAM_SIZE - 1                                                           ;//17 start to process
        parameter TOTAL_LENGTH          =       2 * (BLOCK_RADIUS + WIN_RADIUS) + 1                                     ;//17
        parameter REF_LENGTH            =       2 * BLOCK_RADIUS + 1                                                    ;//5 
        parameter SRH_LENGTH            =       2 * WIN_RADIUS + 1                                                      ;//13       

        input                                                                                   en_i                    ;
        input                                                                                   valid_i                 ;
        input                                                                                   frame_sync_i            ;
        input                                                                                   line_sync_i             ;
        input                                                                                   clk                     ;
        input           [DATA_WIDTH - 1                                 :0]                     pix_i                   ;
        input                                                                                   rst_n                   ;
        output          [TOTAL_LENGTH * DATA_WIDTH - 1                  :0]                     total_blk_o             ;
        output          [REF_LENGTH * DATA_WIDTH - 1                    :0]                     ref_blk_o               ;
        output          [SRH_LENGTH * DATA_WIDTH - 1                    :0]                     srh_blk_o               ;

        wire            [SRAM_SIZE - 1                                  :0]                     sram_rden               ;
        wire            [SRAM_SIZE - 1                                  :0]                     sram_wren               ;
        wire            [ADDR_WIDTH - 1                                 :0]                     sram_addr               ;
        wire            [4                                              :0]                     head_num                ;   
        wire            [(SRAM_SIZE * DATA_WIDTH) - 1                   :0]                     data_block              ;  

        Sram_controller #(      .BLOCK_RADIUS(BLOCK_RADIUS),
                                .WIN_RADIUS(WIN_RADIUS),
                                .ADDR_WIDTH(ADDR_WIDTH),
                                .IMAGE_HEIGHT(IMAGE_HEIGHT),
                                .IMAGE_WIDTH(IMAGE_WIDTH),
                                .DATA_WIDTH(DATA_WIDTH))
        u_Sram_controller(
                .clk(clk),
                .rst_n(rst_n),
                .valid_i(valid_i),
                .en_i(en_i),
                .frame_sync_i(frame_sync_i),
                .line_sync_i(line_sync_i),
                .sram_addr_o(sram_addr),
                .sram_rden_o(sram_rden),
                .sram_wren_o(sram_wren),
                .head_num_o(head_num)
        );

        Memory_block #(         .ADDR_WIDTH(ADDR_WIDTH),
                                .DATA_WIDTH(DATA_WIDTH),
                                .BLOCK_RADIUS(BLOCK_RADIUS),
                                .WIN_RADIUS(WIN_RADIUS))
        u_Memory_block(
                .pix_i(pix_i),
                .sram_addr_i(sram_addr),
                .sram_rden_i(sram_rden),
                .sram_wren_i(sram_wren),
                .data_o(data_block),
                .wrclk(clk),
                .rdclk(clk)
        );

        Memory_output #(        .ADDR_WIDTH(ADDR_WIDTH),
                                .SRH_LENGTH(SRH_LENGTH),
                                .REF_LENGTH(REF_LENGTH),
                                .TOTAL_LENGTH(TOTAL_LENGTH),
                                .DATA_WIDTH(DATA_WIDTH),
                                .BLOCK_RADIUS(BLOCK_RADIUS),
                                .WIN_RADIUS(WIN_RADIUS))
        u_Memory_output(
                .clk(clk),
                .rst_n(rst_n),
                .data_i(data_block),
                .head_num_i(head_num),
                .total_blk_o(total_blk_o),
                .ref_blk_o(ref_blk_o),
                .srh_blk_o(srh_blk_o)
        );

        endmodule