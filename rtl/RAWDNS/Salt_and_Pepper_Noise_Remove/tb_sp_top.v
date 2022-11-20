/***************************************************************************
*
*   Author:       Zhang ZhiHan
*   Date:         2022/11/12
*   Version:      v1.0
*   Note:         the tb file of module sram_controller
*
***************************************************************************/
 `timescale 1ns/1ps
 module tb_sp_top #(parameter   NUM = 5,
                                DATADEPTH = 12,
                                IMG_WIDTH = 1920,
                                IMG_HEIGHT = 1080);
     reg                                                                            clk;
     reg                                                                          rst_n;
     reg                                                                          vsync;
     reg                                                                          hsync;
     reg  [DATADEPTH - 1         : 0]                                            data_i;
     wire [DATADEPTH - 1         : 0]                                            data_o;                                      
     wire                                                                          en_o;
     reg  [DATADEPTH - 1         : 0]              mem_data  [0:IMG_WIDTH*IMG_HEIGHT-1];

     sp_top #(.NUM(5),
              .DATADEPTH(12),
              .IMG_WIDTH(1920),
              .IMG_HEIGHT(1080)) inst0
             ( .clk(clk),
               .rst_n(rst_n),
               .vsync(vsync),
               .hsync(hsync),
               .data_i(data_i),
               .data_o(data_o),
               .en_o(en_o)
             );

     always #10 clk = ~clk;

     initial begin
       clk = 1'b0;rst_n = 1'b0; vsync = 1'b0; hsync = 1'b0;
     end

     initial begin
       $readmemh("sp_1080in.hex",mem_data,0,IMG_WIDTH*IMG_HEIGHT-1);
     end

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
    
     integer text_out;
     initial begin
        text_out = $fopen("C:/Users/LENGION/Desktop/bishe_RTL_Code/Grammatophyllum-RTL/rtl/RAWDNS/Salt_and_Pepper_Noise_Remove/sp_1080out.hex","w");
         if(text_out == 0)begin 
             $display("can not open the file!"); 
             $stop();
         end
     end
    
     integer k = 0;
     always@(posedge clk)
     begin
         //if(k<45000)
         if(k<2083650)
            //$fdisplay(text_out,"%h",data_o);
            $fwrite(text_out,"%h\n",data_o);
         k = k + 1;
     end

     initial begin
         $dumpfile("./build_sp_top/wave.vcd");  // 指定VCD文件的名字为wave.vcd，仿真信息将记录到此文件
         $dumpvars(0, tb_sp_top);  // 指定层次数为0，则tb_code 模块及其下面各层次的�?有信号将被记�?
         #45000000 $finish(); 
         //#1000000 $finish();
     end

endmodule


/*
 module tb_sp_top #(parameter   NUM = 5,
                                DATADEPTH = 12,
                                IMG_WIDTH = 1920,
                                IMG_HEIGHT = 1080);
     reg [DATADEPTH - 1 : 0] ref_mem [0 : IMG_HEIGHT * IMG_WIDTH - 1];
     reg [DATADEPTH - 1 : 0]  out_mem [0 : IMG_HEIGHT * IMG_WIDTH - 1];
     reg [DATADEPTH - 1 : 0]  diff_mem [0 : IMG_HEIGHT * IMG_WIDTH - 1];
     integer ref_file, dump_file;
     initial begin
         $readmemh("sp_ref1080.hex",ref_mem,0,IMG_WIDTH*IMG_HEIGHT-1);
         $readmemh("sp_1080out.hex",out_mem,0,IMG_WIDTH*IMG_HEIGHT-1);
     end     
    
     integer i,j;
     reg signed [DATADEPTH - 1:0] ref_data;
     reg signed [DATADEPTH - 1:0] dump_data;
     reg signed [DATADEPTH - 1:0] diff_data;
     initial begin
     for(i = 0; i< IMG_HEIGHT ; i = i + 1)begin
           for(j = 0 ; j < IMG_WIDTH; j = j + 1)begin
                ref_data = ref_mem[i * IMG_WIDTH + j];
                dump_data = out_mem[i * IMG_WIDTH + j];
                diff_mem[i * IMG_WIDTH + j] = dump_data - ref_data;
            end
     end 
     end

     integer text_out;
     initial begin
        text_out = $fopen("C:/Users/LENGION/Desktop/bishe_RTL_Code/Grammatophyllum-RTL/rtl/RAWDNS/Salt_and_Pepper_Noise_Remove/diff.hex","w");
        if(text_out == 0)begin 
            $display("can not open the file!"); 
            $stop();
        end
     end      
    
     integer k = 0;
    
     initial begin
       for(i = 0; i< IMG_HEIGHT * IMG_WIDTH - 1 ; i = i + 1)begin
             $fwrite(text_out,"%h\n",diff_mem[i]);
       end  
     end  

     integer count = 0;
     initial begin
       for(i = 0; i< IMG_HEIGHT * IMG_WIDTH - 1 ; i = i + 1)begin
             if(diff_mem[i]!=0)begin
               $display("%d",i);
                count = count + 1;   
             end        
       end  
       $display("count = %d\n",count);
     end   
 endmodule
 */