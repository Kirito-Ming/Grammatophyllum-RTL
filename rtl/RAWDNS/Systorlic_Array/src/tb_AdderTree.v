/*******************************************************************/
/*   ModuleName: tb_AdderTree  */
/*   Author: Li tianhao    */
/*   Date: 2022/11/1   */
/*   Version: v1.0      */
/********************************************************************/

`timescale 1ns/1ps

module tb_AdderTree ();
    
    reg clk;
    reg rstn;
    reg [79:0] in_addends;
    wire [18:0] out_sum;
    
    always #5 clk = ~clk;
    
    initial begin
        clk  = 0;
        rstn = 1;
        in_addends = 0;
        repeat(10)@(posedge clk);
        rstn = 0;
        repeat(10)@(posedge clk);
        
        //case1
        in_addends = {16'd567,16'd2434,16'd5,16'd10000,16'd90};
        repeat(20)@(posedge clk);
        
        //case2
        in_addends = {16'd1,16'd2,16'd3,16'd4,16'd5};
        repeat(20)@(posedge clk);
        
        //case3
        in_addends = {16'd1000,16'd2000,16'd3000,16'd5000,16'd1};
        repeat(20)@(posedge clk); 
    end
    
    initial begin
        $dumpfile("./build/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
        $dumpvars(0, tb_AdderTree);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
        #1000$finish;
    end
    
    AdderTree u_AdderTree(
    .in_addends(in_addends),
    .out_sum(out_sum)
    );
    
    
endmodule //tb_AdderTree
