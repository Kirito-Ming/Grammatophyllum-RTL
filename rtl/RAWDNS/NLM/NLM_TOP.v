/********************************************************************
 *
 *   Author:     Liu jiaming
 *   Date:       2022/10/27
 *   Version:    v1.0
 *   Note:       The TOP Architecture of NLM Algorithm
 *
 *********************************************************************/

module NLM_TOP #(parameter  DATA_WIDTH      =   16,
                            BLOCK_RADIUS    =   5,
                            WIN_RADIUS      =   2)
                (   clk,
                    rstn,
                    valid_i,
                    en_i,
                    data_i,
                    frame_sync_i,
                    line_sync_i,
                    config_addr_i,
                    config_data_i,
                    config_en,
                    data_o,
                    frame_sync_o,
                    line_sync_o,
                    valid_o);
    
    input                                           clk;
    input                                           rstn;
    input                                           valid_i;
    input                                           frame_sync_i;
    input                                           line_sync_i;
    input                                           en_i;
    input       [DATA_WIDTH-1           :0]         data_i;
    input       [2                      :0]         config_addr_i;
    input       [15                     :0]         config_data_i;
    input                                           config_en;
    output      [DATA_WIDTH-1           :0]         data_o;
    output                                          valid_o;
    output                                          frame_sync_o;
    output                                          line_sync_o;
    
    
    
    
endmodule
