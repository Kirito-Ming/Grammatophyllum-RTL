/********************************************************************
 *
 *   Author:     Liu jiaming
 *   Date:       2022/10/27
 *   Version:    v1.0
 *   Note:       The simple dual-port sram
 *
 *********************************************************************/

module sram #(parameter ADDR_WIDTH      =  8,
                        DATA_WIDTH      =  16)
            (
                rddata_o        ,
                wraddr_i        ,
                rdaddr_i        ,
                wrdata_i        ,
                wren_i          ,
                rden_i          ,
                wrclk           ,
                rdclk
            );

    parameter   MEM_DEPTH               =       2 ** ADDR_WIDTH                 ;

    output      [DATA_WIDTH-1           :0]         rddata_o                    ;                   //output data
    input       [DATA_WIDTH-1           :0]         wrdata_i                    ;                   //input data
    input       [ADDR_WIDTH-1           :0]         wraddr_i                    ;                   //write data address signal
    input       [ADDR_WIDTH-1           :0]         rdaddr_i                    ;                   //output data address signal
    input                                           wren_i                      ;                   //write data contral signal
    input                                           rden_i                      ;                   //read data contral signal
    input                                           wrclk                       ;                   //write data clock
    input                                           rdclk                       ;                   //read data clock

    reg         [DATA_WIDTH-1           :0]         rddata_o;
    reg         [DATA_WIDTH-1           :0]         mem         [MEM_DEPTH-1:0] ;                   //register

    //writing data
    always@(posedge wrclk)  begin
        if(wren_i) begin
            mem[wraddr_i] <= wrdata_i;
        end
    end

    //reading data 
    always@(posedge rdclk)  begin
        if(rden_i) begin
            rddata_o <= mem[rdaddr_i];
        end   
    end

endmodule