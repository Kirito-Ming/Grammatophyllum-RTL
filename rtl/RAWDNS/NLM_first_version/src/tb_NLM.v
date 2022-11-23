/*******************************************************************/
/*   ModuleName: tb_sramcontroller  */
/*   Author: Li tianhao    */
/*   Date: 2022/11/6   */
/*   Version: v1.0      */
/********************************************************************/

`timescale 1ns/1ps

module tb_NLM ();

parameter FILE_PATH = "E:/HDL/Temp_NLM/src/NLM_in1080.hex";
    reg en_i;
    reg valid_i;
    reg clk;
    reg rst_n;
    reg [11:0] pix_i;
    reg frame_sync_i;
    reg line_sync_i;
    wire [11:0] pix_original;
    wire [11:0] pix_denoise;
    reg [31:0] i;
    wire valid_o;
    wire line_sync_o;
    wire frame_sync_o;

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
        repeat(1079)    begin
        #19190
        line_sync_i = 1;
        #10
        line_sync_i = 0;
        end
        #19190
        valid_i = 0;
    end

    integer fd;
    integer code;
    initial begin
        fd = $fopen(FILE_PATH, "r");
        repeat(20) @(posedge clk);
        for(i = 0; i < 1920 * 1080; i++)      begin
            #10
            code = $fscanf(fd,"%h",pix_i);
        end
        $fclose(fd);
    end
    

    initial begin
        $dumpfile("./build/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
        $dumpvars(0, tb_NLM);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
        #1000000$finish;
    end
    
    NLM u_NLM(
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(valid_i),
        .en_i(en_i),
        .pix_i(pix_i),
        .frame_sync_i(frame_sync_i),
        .line_sync_i(line_sync_i),
        .pix_original(pix_original),
        .pix_denoise(pix_denoise),
        .line_sync_o(line_sync_o),
        .frame_sync_o(frame_sync_o),
        .valid_o(valid_o)
    );
    
    
endmodule //tb_NLM
