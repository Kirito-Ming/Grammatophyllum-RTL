/*******************************************************************/
/*   ModuleName: tb_sramcontroller  */
/*   Author: Li tianhao    */
/*   Date: 2022/11/6   */
/*   Version: v1.0      */
/********************************************************************/

`timescale 1ns/1ps

module tb_Sram_outer ();

    reg en_i;
    reg valid_i;
    reg clk;
    reg rst_n;
    reg [11:0] pix_i;
    reg frame_sync_i;
    reg line_sync_i;
    wire [203:0] total_blk_o;
    wire [155:0] srh_blk_o;
    wire [59:0] ref_blk_o;
    wire [11:0] img_pix_o;
    reg [31:0] i;
    wire valid_o;

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
        repeat(263)    begin
        #4310
        line_sync_i = 1;
        #10
        line_sync_i = 0;
        end
        #4310
        valid_i = 0;
    end

    initial begin
        repeat(20) @(posedge clk);
        for(i = 0; i < 264 * 432; i++)      begin
            #10
            pix_i <= i % 432 + i;
        end
    end
    
    initial begin
        $dumpfile("./build/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
        $dumpvars(0, tb_Sram_outer);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
        #5000000$finish;
    end
    
    Sram_outer u_Sram_outer(
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(valid_i),
        .en_i(en_i),
        .pix_i(pix_i),
        .frame_sync_i(frame_sync_i),
        .line_sync_i(line_sync_i),
        .total_blk_o(total_blk_o),
        .ref_blk_o(ref_blk_o),
        .srh_blk_o(srh_blk_o),
        .img_pix_o(img_pix_o),
        .valid_o(valid_o)
    );
    
    
endmodule //tb_Sram_outer
