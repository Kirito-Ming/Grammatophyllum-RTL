/***************************************************************************
*
*   Author:       Zhang ZhiHan
*   Date:         2022/11/11
*   Version:      v1.0
*   Note:         the cal process of salt and pepper noise detect and remove
*
***************************************************************************/

// 接收来自于SP_SRAM控制阵列的数据:共有4条输出路径
    //路径1: 直接输出来自左上角的两行两列图像数据，为了和形成滑窗时出的第一个计算点对齐,需要打6拍.
          //(cur_y,cur_x) = (2,1)时出第一个左上角点，(cur_y,cur_x) = (4,5)时滑窗填满，计算过程需要两拍节奏((4,7)时滑窗输出左上角第一个计算结果)
          //对齐需要6拍，当through_out_lt有效时，将其与中心点数据进行寄存6拍后判断输出。
    //路径2: 输出中间窗口正确的计算结果(不含窗口滑动至边界时的错误数据列选取)。此时through_out_lt/rd与full_valid均不使能。
    //路径3: 输出窗口滑动至边界时,此时计算结果不正确，直接输出当前位置块中心点代替(信号full_valid有效时，将中心点和full_valid都打2拍后判断有效输出)
    //路径4：输出右下角图像边界，此时需要打两拍以对应窗口的两拍计算延时。
          //信号through_valid_rd拉高后,将data_i[POS_Y]位置数据与through_valid_rd都打两拍后进行判断选取输出

`timescale 1ns/1ps
module sp_noise_removal # (parameter  DATADEPTH =    12,
                                      BWIDTH    =     5,
                                      SIGMA     =   160)
                         (
                                      clk              ,
                                      rst_n            ,
                                      en_i             ,
                                      data_i           ,
                                      lt_through       ,
                                      rd_through       ,
                                      center_through   ,
                                      data_o           ,
                                      pos_y            ,
                                      en_o       
                         );
    parameter QUAN_WIDTH = $clog2(68);
    parameter THRE_WIDTH = QUAN_WIDTH + $clog2(SIGMA);

    input                                                                          clk;      // System clk 
    input                                                                        rst_n;      // System reset signal
    input                                                                         en_i;      // valid_signal from sram controller    
    input           [BWIDTH * DATADEPTH - 1         :0]                         data_i;      // input column data
    input                                                                   lt_through;      // Signal of through out the LT 2rows and 2cols data in 
                                                                                                // fetch data from the input column ,the pos_y data
    input                                                                   rd_through;      // Signal of through out the RD 2rows and 2cols data in
                                                                                                // fetch data from the input column ,the pos_y data
    input                                                               center_through;      // Signal of through out the center point in the SP cal window
                                                                                                // when this signal ups, through the center pix in the cal window
    input           [2                              :0]                          pos_y;      // The data fecth pos signal of input column data in state lt_through and rd_through                                                             
    output reg      [DATADEPTH - 1                  :0]                         data_o;      // The output data,onr 
    output reg                                                                    en_o;      

    reg             [DATADEPTH - 1                          :0]   grad_h_r1, grad_h_r2;      // The Sub Grad Value in the H direction
    reg             [DATADEPTH - 1                          :0]   grad_v_r1, grad_v_r2;      // The Sub Grad Value in the V direction
    reg             [DATADEPTH - 1                          :0]   grad_d_r1, grad_d_r2;      // The Sub Grad Value in the D direction (45 degree)
    reg             [DATADEPTH - 1                          :0]   grad_z_r1, grad_z_r2;      // The Sub Grad Value in the Z direction (135 degree)

    reg             [DATADEPTH                              :0]   grad_h_r;                  // The Total Grad Value in the H direction
    reg             [DATADEPTH                              :0]   grad_v_r;                  // The Total Grad Value in the V direction
    reg             [DATADEPTH                              :0]   grad_d_r;                  // The Total Grad Value in the D direction
    reg             [DATADEPTH                              :0]   grad_z_r;                  // The Total Grad Value in the Z direction
    wire            [DATADEPTH                              :0]   grad_min;                  // The Min Value of thee total Grad Value 

    reg             [DATADEPTH                              :0]   h_intp1_r1, h_intp1_r2;    // The Sub Intp Value in the H direction
    reg             [DATADEPTH                              :0]   v_intp1_r1, v_intp1_r2;    // The Sub Intp Value in the V direction
    reg             [DATADEPTH                              :0]   d_intp1_r1, d_intp1_r2;    // The Sub Intp Value in the D direction
    reg             [DATADEPTH                              :0]   z_intp1_r1, z_intp1_r2;    // The Sub Intp Value in the Z direction

    reg             [DATADEPTH                              :0]   intp_h_r;                  // The Total Intp Value in the H direction
    reg             [DATADEPTH                              :0]   intp_v_r;                  // The Total Intp Value in the V direction
    reg             [DATADEPTH                              :0]   intp_d_r;                  // The Total Intp Value in the D direction
    reg             [DATADEPTH                              :0]   intp_z_r;                  // The Total Intp Value in the Z direction

    reg             [DATADEPTH                              :0]   intp_result;               // The Intp result for all direction
    wire            [DATADEPTH  - 1                         :0]   intp_cliped;               // The final intp result
    reg             [DATADEPTH  - 1                         :0]   intp_cliped_r;

    wire            [THRE_WIDTH - 1                         :0]   thre_w;                    // The Salt and Pepper noise judge threhold
    reg             [BWIDTH * DATADEPTH-1                   :0]   cal_block_r  [0    :BWIDTH - 1];  // The Cal Window of Salt and Pepper Noise Correction
  
    //左上角输出旁路信号(打7拍来与第一个划窗填满时的流水计算输出对齐,5拍为填满窗口，2拍为计算延时)
    reg                                                           lt_out_valid [0:6];
    reg             [DATADEPTH  - 1                         :0]   lt_out_data  [0:6];

    //右下角输出旁路信号(打4拍，2拍为划窗流水的计算延时，2拍为数据进入的延时)
    reg                                                           rd_out_valid [0:3];
    reg             [DATADEPTH  - 1                         :0]   rd_out_data  [0:3];

    //每当划窗划到每行最右边和最左边时,窗口新进入的数据是无效的(与当前窗进入的数据不为同行的一列，数据错乱),(打3拍)
    reg                                                           center_out_valid[0:2];
    reg             [DATADEPTH  - 1                         :0]   center_out_data[0:2];
    reg             [DATADEPTH  - 1                         :0]   center_out_r6;
   
    //窗口正确形成时的输出信号
    reg             [DATADEPTH  - 1                         :0]   window_out;
    genvar i,j;


    //1.图像中心块计算逻辑
        //计算窗口滑动    
        generate 
            for(i = 0; i < BWIDTH; i = i + 1)begin: out_window_refresh_loop     
                for(j = 1; j<= BWIDTH; j = j + 1)begin: inner_wnidow_refresh_loop
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)
                        cal_block_r[i][((j + 1) * DATADEPTH - 1)-:DATADEPTH] <= 0;
                    else 
                        cal_block_r[i][((j + 1) * DATADEPTH - 1)-:DATADEPTH] <= cal_block_r[i][(j * DATADEPTH - 1)-:DATADEPTH];
                end
            end
            end
        endgenerate
        

        //窗口数据进入
        generate 
            for(i = 0;i < BWIDTH; i = i + 1)begin
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        cal_block_r[i][DATADEPTH - 1 :0] <= 0;
                    end
                    else 
                        cal_block_r[i][DATADEPTH - 1 :0] <= data_i[((BWIDTH - i) * DATADEPTH - 1)-:DATADEPTH];
                end
            end
        endgenerate


        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
                center_out_r6 <= 0;
            else              
                center_out_r6 <= cal_block_r[2][(5 * DATADEPTH - 1)-:DATADEPTH];
        end

        //tap one: cal the sub_grads in the block
            //cal the grad in h direction
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                grad_h_r1 <= 0;
                grad_h_r2 <= 0;
            end
            else begin
                grad_h_r1 <= abs (cal_block_r[BWIDTH/2][DATADEPTH - 1:0],cal_block_r[BWIDTH/2][(BWIDTH*DATADEPTH - 1)-:DATADEPTH]);  //abs(31-35)
                grad_h_r2 <= abs (cal_block_r[BWIDTH/2][(2 * DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH/2][((BWIDTH - 1) *DATADEPTH - 1)-:DATADEPTH]); //abs(32-34)
            end
        end

            //cal the grad in v direction
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin          
                grad_v_r1 <= 0;
                grad_v_r2 <= 0;
            end
            else begin     
                grad_v_r1 <= abs(cal_block_r[0][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 1][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH]); //abs(13-53)
                grad_v_r2 <= abs(cal_block_r[1][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 2][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH]); //abs(23-43)
            end
        end

            //cal the grad in 45 degree direction
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin  
                grad_d_r1 <= 0;
                grad_d_r2 <= 0;
            end
            else begin                                                         
                grad_d_r1 <= abs(cal_block_r[0][(DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 1][(BWIDTH * DATADEPTH - 1)-:DATADEPTH]); //abs(15-51)
                grad_d_r2 <= abs(cal_block_r[1][(2*DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 2][((BWIDTH - 1) * DATADEPTH - 1)-:DATADEPTH]); //abs(24-42)
            end 
        end

            //cal the grad in 135 degree direction
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin 
                grad_z_r1 <= 0;
                grad_z_r2 <= 0;
            end
            else begin
                grad_z_r1 <= abs(cal_block_r[0][(BWIDTH*DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 1][(DATADEPTH - 1)-:DATADEPTH]); //abs(11-55)
                grad_z_r2 <= abs(cal_block_r[1][((BWIDTH - 1) *DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 2][(2 * DATADEPTH - 1)-:DATADEPTH]); //abs(22-44) 
            end
        end 

        
        //tap one: cal the sub_intps in the block
            // cal the intp result in h direction
    always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                h_intp1_r1 <= 0;
                h_intp1_r2 <= 0;
            end
            else begin
                h_intp1_r1 <= (cal_block_r[BWIDTH/2][DATADEPTH - 1:0] + cal_block_r[BWIDTH/2][(BWIDTH*DATADEPTH - 1)-:DATADEPTH] + 1)/2; //(31 + 35 + 1)/2;
                h_intp1_r2 <= (abs(cal_block_r[BWIDTH/2][(2 * DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH/2][((BWIDTH - 1) *DATADEPTH - 1)-:DATADEPTH]) + 1)/2; //(34 + 32 + 1)/2
            end
        end

        // cal the intp result in v direction
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                v_intp1_r1 <= 0;
                v_intp1_r2 <= 0;
            end
            else begin
                v_intp1_r1 <= (cal_block_r[0][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH] + cal_block_r[BWIDTH - 1][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH] + 1)/2; //(13 + 53 + 1)/2
                v_intp1_r2 <= (abs(cal_block_r[1][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 2][((BWIDTH/2 + 1) * DATADEPTH - 1)-:DATADEPTH]) + 1)/2;  //(23 + 43 + 1)/2
            end
        end

        // cal the intp result in d direction，45 degree
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                d_intp1_r1 <= 0;
                d_intp1_r2 <= 0;
            end
            else begin
                d_intp1_r1 <= (cal_block_r[0][(DATADEPTH - 1)-:DATADEPTH] + cal_block_r[BWIDTH - 1][(BWIDTH * DATADEPTH - 1)-:DATADEPTH] + 1)/2; //(15 + 51 + 1)/2
                d_intp1_r2 <= (abs(cal_block_r[1][(2*DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 2][((BWIDTH - 1) * DATADEPTH - 1)-:DATADEPTH]) + 1)/2;  //abs(24 + 42 + 1)/2
            end
        end

        //cal the intp result in the z direction,135 degree
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                z_intp1_r1 <= 0;
                z_intp1_r2 <= 0;
            end
            else begin
                z_intp1_r1 <= (cal_block_r[0][(BWIDTH*DATADEPTH - 1)-:DATADEPTH] + cal_block_r[BWIDTH - 1][(DATADEPTH - 1)-:DATADEPTH] + 1)/2; //(11 + 55 + 1)/2
                z_intp1_r2 <= (abs(cal_block_r[1][((BWIDTH - 1) *DATADEPTH - 1)-:DATADEPTH],cal_block_r[BWIDTH - 2][(2 * DATADEPTH - 1)-:DATADEPTH]) + 1)/2; //(abs(22-44) + 1)/2
            end
        end

        //tap two: adder the mid_intp and mid_grad
        //cal the final grad
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                grad_h_r <= 0;
                grad_v_r <= 0;
                grad_d_r <= 0;
                grad_z_r <= 0;
            end
            else  begin
                grad_h_r <= grad_h_r1 + grad_h_r2;
                grad_v_r <= grad_v_r1 + grad_v_r2;
                grad_d_r <= grad_d_r1 + grad_d_r2;
                grad_z_r <= grad_z_r1 + grad_z_r2;
            end
        end

        //cal the final intp
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n) begin
                intp_h_r <= 0;
                intp_v_r <= 0;
                intp_d_r <= 0;
                intp_z_r <= 0;
            end
            else begin
                intp_h_r <= h_intp1_r1 + h_intp1_r2;
                intp_v_r <= v_intp1_r1 + v_intp1_r2;
                intp_d_r <= d_intp1_r1 + d_intp1_r2;
                intp_z_r <= z_intp1_r1 + z_intp1_r2;
            end
        end

        //find the min grad direction and correct result
        min#(.DATADEPTH(DATADEPTH + 1))inst1(.op1(grad_h_r), .op2(grad_v_r), .op3(grad_d_r),.op4(grad_z_r),.min(grad_min));
        always@(*)begin
            case(grad_min)
            grad_h_r:
                intp_result =   intp_h_r;
            grad_v_r:
                intp_result =   intp_v_r;
            grad_d_r:
                intp_result =   intp_d_r;
            grad_z_r:
                intp_result =   intp_z_r;
            default:
                intp_result =          0;
            endcase
        end

        assign intp_cliped = intp_result > 4095?4095:intp_result;
        assign thre_w = (SIGMA * 68) >> 4;
        
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
                intp_cliped_r <= 0;
            else 
                intp_cliped_r <= intp_cliped;
        end

        always@(*)begin
            window_out = cal_block_r[2][(3*DATADEPTH - 1)-:DATADEPTH];    
        end

        function [DATADEPTH:0]  abs;
            input [DATADEPTH-1:0] op1;
            input [DATADEPTH-1:0] op2;
            abs = op1 > op2 ? op1 - op2:op2 - op1;
        endfunction
    
    //2.左上角图像输出逻辑
        //输入有效信号寄存
        generate
            for(i = 1; i < 7 ; i = i + 1)begin:lt_valid_loop
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        lt_out_valid[i] <= 0;
                    end
                    else begin
                        lt_out_valid[i] <=  lt_out_valid[i - 1]; 
                    end
                end 
            end
        endgenerate

        always@(posedge clk or negedge rst_n)begin
                if(!rst_n)begin
                    lt_out_valid[0] <= 0;
                end
                else begin
                    lt_out_valid[0] <=  lt_through; 
                end

        end

        //输入有效数据寄存
        generate
            for(i = 1; i < 7; i = i + 1)begin:lt_data_loop
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        lt_out_data[i][(DATADEPTH - 1)-:DATADEPTH] <= 0;
                    end
                    else begin
                        lt_out_data[i][(DATADEPTH - 1)-:DATADEPTH] <= lt_out_data[i - 1][(DATADEPTH - 1)-:DATADEPTH];
                    end
                end 
            end
        endgenerate

        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                lt_out_data[0][(DATADEPTH - 1)-:DATADEPTH] <= 0;
            end
            else begin
                lt_out_data[0][(DATADEPTH - 1)-:DATADEPTH] <= data_i[((BWIDTH - pos_y)*DATADEPTH - 1)-:DATADEPTH];
            end
        end

    //3.中间图像输出逻辑 
        //输入有效信号寄存
        generate
            for(i = 1; i < 3 ; i = i + 1)begin: center_valid_loop
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        center_out_valid[i] <= 0;
                    end
                    else begin
                        center_out_valid[i] <=  center_out_valid[i - 1]; 
                    end
                end 
            end
        endgenerate

        always@(posedge clk or negedge rst_n)begin
                if(!rst_n)begin
                    center_out_valid[0] <= 0;
                end
                else begin
                    center_out_valid[0] <=  center_through; 
                end

        end

        //输入有效数据寄存
        generate
            for(i = 1; i < 3; i = i + 1)begin: center_data_loop
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        center_out_data[i][(DATADEPTH - 1)-:DATADEPTH] <= 0;
                    end
                    else begin
                        center_out_data[i][(DATADEPTH - 1)-:DATADEPTH] <= center_out_data[i - 1][(DATADEPTH - 1)-:DATADEPTH];
                    end
                end 
            end
        endgenerate

        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                center_out_data[0][(DATADEPTH - 1)-:DATADEPTH] <= 0;
            end
            else begin
                center_out_data[0][(DATADEPTH - 1)-:DATADEPTH] <= cal_block_r[2][(3*DATADEPTH - 1)-:DATADEPTH];
            end
        end

    //右下角图像输出逻辑 
        //输入有效信号寄存，寄存4拍
         generate
            for(i = 1; i < 4 ; i = i + 1)begin: rd_valid_loop
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        rd_out_valid[i] <= 0;
                    end
                    else begin
                        rd_out_valid[i] <=  rd_out_valid[i - 1]; 
                    end
                end 
            end
        endgenerate

        always@(posedge clk or negedge rst_n)begin
                if(!rst_n)begin
                    rd_out_valid[0] <= 0;
                end
                else begin
                    rd_out_valid[0] <= rd_through; 
                end

        end

        //输入有效数据寄存
        generate
            for(i = 1; i < 4; i = i + 1)begin: rd_data_loop
                always@(posedge clk or negedge rst_n)begin
                    if(!rst_n)begin
                        rd_out_data[i][(DATADEPTH - 1)-:DATADEPTH] <= 0;
                    end
                    else begin
                        rd_out_data[i][(DATADEPTH - 1)-:DATADEPTH] <= rd_out_data[i - 1][(DATADEPTH - 1)-:DATADEPTH];
                    end
                end 
            end
        endgenerate

        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                rd_out_data[0][(DATADEPTH - 1)-:DATADEPTH] <= 0;
            end
            else begin
                rd_out_data[0][(DATADEPTH - 1)-:DATADEPTH] <= data_i[((BWIDTH - pos_y)*DATADEPTH - 1)-:DATADEPTH];
            end
        end

    reg [DATADEPTH - 1 :0] window_out_r1, window_out_r2, window_out_r3;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            {window_out_r1 , window_out_r2, window_out_r3} <= 0;
        end
        else begin
            {window_out_r1 , window_out_r2, window_out_r3} <= {window_out, window_out_r1, window_out_r2};
        end
    end

    //根据情况选择不同的旁路输出
    reg [DATADEPTH - 1:0] Mux_out;
    always@(*)begin
        if(lt_out_valid[6]) //左上角直接输出的两行两列数据与滑窗填满时的6拍输出间间隔5拍的延时，划窗填满至弹出前一个中心点3拍，划窗计算2拍延时(例如(count_y_r,count_x_r) = (4,3)时SRAM读出位置(4,1)的点，在(4,6)时将(4,4)列弹入并装满划窗)
            Mux_out = lt_out_data[5][(DATADEPTH - 1)-:DATADEPTH];
        else if(rd_out_valid[3])//4拍，到时候就写2拍延时，划窗计算延时
            Mux_out = rd_out_data[3][(DATADEPTH - 1)-:DATADEPTH];
        else if(center_out_valid[2]) //3拍，到时候就写两拍延时,SP模块计算时长
            Mux_out = center_out_data[2][(DATADEPTH - 1)-:DATADEPTH];
        else begin
            if((((center_out_r6 == 4095) || (center_out_r6 == 0)) && (abs(intp_cliped_r,center_out_r6) > thre_w)))
                Mux_out = intp_cliped_r;
            else
                Mux_out = window_out_r3;
        end
    end
    
    //打拍en_o信号以去除最后几拍的无效输出
    integer k;
    reg en_o_r[0:5];
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            for(k = 1 ;k < 6 ;k = k + 1)begin
                en_o_r[k]<= 0;
            end
        else
           en_o_r[k]<= en_o_r[k - 1];
    end
    
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            en_o_r[0] <= 0;
        else
            en_o_r[0] <= en_o;
    end

    //为了保证最后4拍无效输出屏蔽，加下降沿判断逻辑
    reg down;
    assign rd_fall_edge = ~rd_out_valid[2] && rd_out_valid[3];
    
    always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
                down <= 0;
            else if(rd_fall_edge)
                down <= 1;
    end

    always@(*)begin
         data_o = (en_o && !down)?Mux_out:0;
    end
endmodule