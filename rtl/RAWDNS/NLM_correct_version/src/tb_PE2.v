/*******************************************************************/
/*   ModuleName: tb_PE2  */
/*   Author: Li tianhao    */
/*   Date: 2022/11/1   */
/*   Version: v1.0      */
/********************************************************************/

`timescale 1ns/1ps

module tb_PE2 ();
    
    reg clk;
    reg rstn;
    reg [7:0]  weight_i;
    reg [11:0]  srh_blk_i; 
    reg [25:0]  pix_sum_i;
    reg [13:0]  weight_sum_i;
    wire [25:0]  pix_sum_o;
    wire [13:0]  weight_sum_o;
    
    always #5 clk = ~clk;
    
    initial begin
        clk  = 0;
        rstn = 0;
        weight_i = 0;
        srh_blk_i = 0;
        pix_sum_i = 0;
        weight_sum_i = 0;
        repeat(10)@(posedge clk);
        rstn = 1;
        repeat(10)@(posedge clk);
        
        //case1
        weight_i <= 1;
        srh_blk_i <= 100;
        pix_sum_i <= 0;
        weight_sum_i <= 0;
        repeat(20)@(posedge clk);
        
        //case2
        weight_i <= 5;
        srh_blk_i <= 30;
        pix_sum_i <= 250;
        weight_sum_i <= 50;
        repeat(20)@(posedge clk);
        
        //case3
        weight_i <= 900;
        srh_blk_i <= 22;
        pix_sum_i <= 5000;
        weight_sum_i <= 25859;
        repeat(20)@(posedge clk); 
    end
    
    initial begin
        $dumpfile("./build/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
        $dumpvars(0, tb_PE2);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
        #10000$finish;
    end
    
    PE2 u_PE2(
    .clk  (clk),
    .rst_n (rstn),
    .weight_i(weight_i),
    .srh_bit_i(srh_blk_i),
    .pix_sum_i(pix_sum_i),
    .weight_sum_i(weight_sum_i),
    .pix_sum_o(pix_sum_o),
    .weight_sum_o(weight_sum_o)
    );
    
    
endmodule //tb_PE2
