/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/12
 *   Version:    v1.0
 *   Note:       Memory_block
 *
 *********************************************************************/

module Memory_block #(parameter     ADDR_WIDTH      =  12,
                                    DATA_WIDTH      =  12,
                                    BLOCK_RADIUS    =  2,
                                    WIN_RADIUS      =  6)
            (
                pix_i,
                sram_addr_i,
                sram_wren_i,
                sram_rden_i,
                data_o,
                wrclk,
                rdclk,
            );

    parameter   MEM_DEPTH               =       2 ** ADDR_WIDTH                                                 ;
    parameter   SRAM_SIZE               =       2 * (BLOCK_RADIUS + WIN_RADIUS + 1)                             ;

    input               [DATA_WIDTH - 1                     :0]                 pix_i                           ;
    input               [ADDR_WIDTH - 1                     :0]                 sram_addr_i                     ;
    input               [SRAM_SIZE - 1                      :0]                 sram_wren_i                     ;
    input               [SRAM_SIZE - 1                      :0]                 sram_rden_i                     ;
    input                                                                       wrclk                           ;
    input                                                                       rdclk                           ;
    output              [(SRAM_SIZE * DATA_WIDTH) - 1       :0]                 data_o                          ;

    genvar i;
    generate for(i = 0; i < SRAM_SIZE; i = i + 1)   begin
        sram #(.ADDR_WIDTH(ADDR_WIDTH),.DATA_WIDTH(DATA_WIDTH))
        u_sram(
            .rddata_o(data_o[DATA_WIDTH * (i + 1) - 1 : DATA_WIDTH * i]),
            .wraddr_i(sram_addr_i),
            .rdaddr_i(sram_addr_i),
            .wrdata_i(pix_i),
            .wren_i(sram_wren_i[i]),
            .rden_i(sram_rden_i[i]),
            .wrclk(wrclk),
            .rdclk(rdclk)
        );
    end
    endgenerate

endmodule