/*******************************************************************/
/*   ModuleName: tb_sramcontroller  */
/*   Author: Li tianhao    */
/*   Date: 2022/11/6   */
/*   Version: v1.0      */
/********************************************************************/

`timescale 1ns/1ps

module tb_sramcontroller ();
    wire [17:0] sram_rden_o;
    reg en_i;
    reg valid_i;
    reg clk;
    reg rst_n;
    reg frame_sync_i;
    reg line_sync_i;
    wire [17:0] sram_wren_o;
    wire [11:0] sram_addr_o;
    wire [4:0]  head_num_o;

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        valid_i = 0;
        en_i = 0;
        frame_sync_i = 0;
        line_sync_i = 0;
        repeat(10)@(posedge clk);
        rst_n = 1;
        repeat(10)@(posedge clk);
        #10
        frame_sync_i = 1;
        line_sync_i = 1;
        valid_i = 1;
        en_i = 1;
        #10
        frame_sync_i = 0;
        line_sync_i = 0;
        repeat(3023)    begin
        #100
        line_sync_i = 1;
        #10
        line_sync_i = 0;
        end
        #100
        valid_i = 0;
    end
    
    initial begin
        $dumpfile("./build/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
        $dumpvars(0, tb_sramcontroller);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
        #1000000$finish;
    end
    
    Sram_controller u_sramcontroller(
        .sram_rden_o(sram_rden_o),
        .en_i(en_i),
        .valid_i(valid_i),
        .line_sync_i(line_sync_i),
        .frame_sync_i(frame_sync_i),
        .clk(clk),
        .rst_n(rst_n),
        .sram_addr_o(sram_addr_o),
        .sram_wren_o(sram_wren_o),
        .head_num_o(head_num_o)
    );
    
    
endmodule //tb_sramcontroller
