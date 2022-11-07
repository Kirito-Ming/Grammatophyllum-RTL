/*******************************************************************/
/*   ModuleName: tb_PE1  */
/*   Author: Li tianhao    */
/*   Date: 2022/11/1   */
/*   Version: v1.0      */
/********************************************************************/

`timescale 1ns/1ps

module tb_PE ();
    
    reg clk;
    reg rstn;
    reg [31:0] pix_sum_i;
    reg [31:0] weight_sum_i;
    reg [175:0]  total_blk_i; 
    reg [111:0]  srh_blk_i;
    reg [79:0]  ref_blk_i;
    wire [175:0]  total_blk_o;
    wire [111:0]  srh_blk_o;
    wire [79:0] ref_blk_o;
    wire [31:0] weight_sum_o;
    wire [31:0] pix_sum_o;

    
    always #10 clk = ~clk;
    
    initial begin
        clk  = 0;
        rstn = 0;
        pix_sum_i = 100;
        weight_sum_i = 10000;
        repeat(10)@(posedge clk);
        rstn = 1;
        repeat(10)@(posedge clk);
        #19
        //case1
        srh_blk_i = {16'd10,16'd9,16'd8,16'd7,16'd6,16'd5,16'd4};
        total_blk_i = {16'd1,16'd2,16'd3,16'd4,16'd5,16'd0,16'd0,16'd0,16'd0,16'd0,16'd0};
        ref_blk_i = {16'd0,16'd1,16'd2,16'd3,16'd4};
        #21;
        //case2
        srh_blk_i = {16'd10,16'd9,16'd8,16'd7,16'd6,16'd5,16'd5};
        total_blk_i = {16'd1,16'd2,16'd3,16'd4,16'd5,16'd0,16'd0,16'd0,16'd0,16'd0,16'd0};
        ref_blk_i = {16'd10,16'd20,16'd30,16'd40,16'd50};
        #20;
        //case3
        srh_blk_i = {16'd10,16'd9,16'd8,16'd7,16'd6,16'd5,16'd6};
        total_blk_i = {16'd1,16'd2,16'd3,16'd4,16'd5,16'd0,16'd0,16'd0,16'd0,16'd0,16'd0};
        ref_blk_i = {16'd20,16'd30,16'd40,16'd50,16'd60};
        #20;
        //case4
        srh_blk_i = {16'd10,16'd9,16'd8,16'd7,16'd6,16'd5,16'd7};
        total_blk_i = {16'd1,16'd2,16'd3,16'd4,16'd5,16'd0,16'd0,16'd0,16'd0,16'd0,16'd0};
        ref_blk_i = {16'd30,16'd40,16'd50,16'd60,16'd70};
        #20;
        //case5
        srh_blk_i = {16'd10,16'd9,16'd8,16'd7,16'd6,16'd5,16'd8};
        total_blk_i = {16'd1,16'd2,16'd3,16'd4,16'd5,16'd0,16'd0,16'd0,16'd0,16'd0,16'd0};
        ref_blk_i = {16'd40,16'd50,16'd60,16'd70,16'd80};
        #20;
        //case6
        srh_blk_i = {16'd1,16'd2,16'd3,16'd4,16'd5,16'd6,16'd9};
        total_blk_i = {16'd2,16'd3,16'd4,16'd5,16'd6,16'd0,16'd0,16'd1,16'd2,16'd3,16'd4};
        ref_blk_i = {16'd50,16'd60,16'd70,16'd80,16'd90};
        #20;
        //case7
        srh_blk_i = {16'd10,16'd9,16'd8,16'd7,16'd6,16'd5,16'd10};
        total_blk_i = {16'd1,16'd2,16'd3,16'd4,16'd5,16'd0,16'd0,16'd0,16'd0,16'd0,16'd0};
        ref_blk_i = {16'd60,16'd70,16'd80,16'd90,16'd100};
    end
    
    initial begin
        $dumpfile("./build/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
        $dumpvars(0, tb_PE);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
        #10000$finish;
    end
    
    PE u_PE(
    .clk  (clk),
    .rst_n (rstn),
    .total_blk_i(total_blk_i),
    .srh_blk_i(srh_blk_i),
    .ref_blk_i(ref_blk_i),
    .pix_sum_i(pix_sum_i),
    .weight_sum_i(weight_sum_i),
    .ref_blk_o(ref_blk_o),
    .srh_blk_o(srh_blk_o),
    .total_blk_o(total_blk_o),
    .pix_sum_o(pix_sum_o),
    .weight_sum_o(weight_sum_o)
    );
    
    
endmodule //tb_PE
