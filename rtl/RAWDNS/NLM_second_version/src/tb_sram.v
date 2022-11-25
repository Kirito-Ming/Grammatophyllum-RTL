/*******************************************************************/
/*   ModuleName: tb_sram  */
/*   Author: Li tianhao    */
/*   Date: 2022/11/6   */
/*   Version: v1.0      */
/********************************************************************/

`timescale 1ns/1ps

module tb_sram ();
    
    reg wrclk;
    reg rdclk;
    wire [15:0] rddata_o;
    reg [15:0] wrdata_i;
    reg [11:0] rdaddr_i;
    reg [11:0] wraddr_i;
    reg wren_i;
    reg rden_i;
    reg clk;

    always #5 clk = ~clk;
    always #5 wrclk = ~wrclk;
    always #5 rdclk = ~rdclk;

    initial begin
        clk = 0;
        wrclk = 0;
        rdclk = 0;
        repeat(10)@(posedge clk);
        
        //case1
        wren_i = 1;
        wrdata_i = 50;
        wraddr_i = 100;
        rden_i = 0;
        rdaddr_i = 0;
        #10
        //case2
        wren_i = 1;
        wrdata_i = 100;
        wraddr_i = 200;
        rden_i = 0;
        rdaddr_i = 0;
        #10
        rdaddr_i = 200;
        wren_i = 0;
        wrdata_i = 0;
        wraddr_i = 0;
        rden_i = 1;
        
        #10
        wren_i = 0;
        wrdata_i = 0;
        wraddr_i = 0;
        rden_i = 1;
        rdaddr_i = 100;

    end
    
    initial begin
        $dumpfile("./build/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
        $dumpvars(0, tb_sram);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
        #10000$finish;
    end
    
    sram u_sram(
        .rdaddr_i(rdaddr_i),
        .rddata_o(rddata_o),
        .rden_i(rden_i),
        .rdclk(rdclk),
        .wren_i(wren_i),
        .wraddr_i(wraddr_i),
        .wrdata_i(wrdata_i),
        .wrclk(wrclk)
    );
    
    
endmodule //tb_sram
