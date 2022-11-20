/***************************************************************************
*
*   Author:       Zhang ZhiHan
*   Date:         2022/11/12
*   Version:      v1.0
*   Note:         the tb file of module sram_controller
*
***************************************************************************/
`timescale 1ns/1ps
module tb_sram_controller #(parameter   NUM = 5,
                                        DATADEPTH = 12,
                                        IMG_WIDTH = 1920,
                                        IMG_HEIGHT = 10);
    reg                                                                            clk;
    reg                                                                          rst_n;
    reg                                                                          vsync;
    reg                                                                          hsync;
    reg  [DATADEPTH - 1         : 0]                                            data_i;
    wire [NUM*DATADEPTH - 1     : 0]                                            data_o;
    wire                                                              through_valid_lt;
    wire                                                              through_valid_rd;
    wire                                                                    full_valid;
    wire [$clog2(NUM) -1        : 0]                                             pos_y;                                       
    wire                                                                          en_o;
    reg  [DATADEPTH - 1         : 0]               mem_data [0:IMG_WIDTH*IMG_HEIGHT-1];

    sram_controller #(.NUM(5),
                      .DATADEPTH(12),
                      .IMG_WIDTH(1920),
                      .IMG_HEIGHT(10)) inst0
                     ( .clk(clk),
                       .rst_n(rst_n),
                       .vsync(vsync),
                       .hsync(hsync),
                       .data_i(data_i),
                       .data_o(data_o),
                       .through_valid_lt(through_valid_lt),
                       .through_valid_rd(through_valid_rd),
                       .full_valid(full_valid),
                       .pos_y(pos_y),
                       .en_o(en_o)
                     );

    always #10 clk = ~clk;

    initial begin
      clk = 1'b0;rst_n = 1'b0; vsync = 1'b0; hsync = 1'b0;
    end

    initial begin
      $readmemh("small.hex",mem_data,0,IMG_WIDTH*IMG_HEIGHT-1);
    end

    //后续将添加hsync的同步逻辑
    integer i , j , p = 0;
    initial begin
    #100 rst_n = 1'b1;
    #100 vsync = 1'b1; hsync = 1'b1;
    //@(posedge clk);
    for(i = 0; i< IMG_HEIGHT ; i = i + 1)begin
            hsync = 1; 
            for(j = 0 ; j < IMG_WIDTH; j = j + 1)begin
                data_i = mem_data[p];
                p = p + 1;
                @(posedge clk);
                hsync = 0;vsync = 0;
            end
         end 
    end
    
    initial begin
      $dumpfile("./build_sp_sram_controller/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
      $dumpvars(0, tb_sram_controller);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
      #500000 $finish(); 
    end
endmodule