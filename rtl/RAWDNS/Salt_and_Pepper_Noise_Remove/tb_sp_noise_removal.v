/***************************************************************************
*
*   Author:       Zhang ZhiHan
*   Date:         2022/11/11
*   Version:      v1.0
*   Note:         the tb file of module sp_noise_removal
*
***************************************************************************/
`timescale 1ns/1ps
module tb_sp_noise_removal;
reg                                                      clk;
reg                                                    rst_n;
reg                                                     en_i;
reg                     [59:0]                        data_i;   
wire                    [11:0]                        data_o;
wire                                                    en_o;

sp_noise_removal  #(.DATADEPTH(12),
                    .BWIDTH(5),
                    .SIGMA(160)) 
            inst0  (
                    .clk(clk),
                    .rst_n(rst_n),
                    .en_i(en_i),
                    .data_i(data_i),
                    .data_o(data_o),
                    .en_o(en_o)     
                    );

always #10 clk = ~clk;

initial begin
    clk = 1'b0;rst_n = 1'b0;en_i = 1'b0;
end

initial begin
#100 rst_n = 1'b1;
#110 en_i = 1'b1; data_i = {12'd299,12'd745,12'd558,12'd895,12'd701};
#20  data_i = {12'd845,12'd136,12'd843,12'd294,12'd731};
#20  data_i = {12'd913,12'd426,12'd4095,12'd635,12'd801};
#20  data_i = {12'd913,12'd426,12'd178,12'd635,12'd801};
#20  data_i = {12'd139,12'd496,12'd1596,12'd2527,12'd136}; 
#300 $finish();
end

initial begin
    $dumpfile("./build_sp_cal/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
    $dumpvars(0, tb_sp_noise_removal);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
    #10000$finish;
end

endmodule
