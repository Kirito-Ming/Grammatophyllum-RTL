/***************************************************************************
*
*   Author:       Zhang ZhiHan
*   Date:         2022/11/11
*   Version:      v1.0
*   Note:         the cal process of salt and pepper noise detect and remove
*
***************************************************************************/

// Need (BWIDTH + 1) Taps from the first colomn data input and useful output
// (BWIDTH - 1) taps for data fill full for the window, 2 taps for noise removal  
`timescale 1ns/1ps
module sp_noise_removal # (parameter  DATADEPTH =    12,
                                      BWIDTH    =     5,
                                      SIGMA     =   160)
                         (
                            clk        ,
                            rst_n      ,
                            en_i       ,
                            data_i     ,
                            data_o     ,
                            en_o       
                         );
    parameter QUAN_WIDTH = $clog2(68);
    parameter THRE_WIDTH = QUAN_WIDTH + $clog2(SIGMA);

    input                                                                          clk;      // System clk 
    input                                                                        rst_n;      // System reset signal
    input                                                                         en_i;      // Valid signal of the input column data
    input           [DATADEPTH * BWIDTH - 1         :0]                         data_i;      // The input Column data  
    output reg      [DATADEPTH - 1                  :0]                         data_o;      // The Salt and Pepper noise correct out data
    output reg                                                                    en_o;      // The Valid signal of the output SP noise correct data

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


    wire            [THRE_WIDTH - 1                         :0]   thre_w;                    // The Salt and Pepper noise judge threhold

    reg             taps    [0                         :BWIDTH];                             // Taps for the valid column data in to the valid data_out
    reg             [DATADEPTH - 1                          :0]   center_tap1, center_tap2;  // The Taps of the Center Point in the Cal Window
    reg             [BWIDTH * DATADEPTH-1                   :0]   cal_block_r  [0    :BWIDTH -1];  // The Cal Window of Salt and Pepper Noise Correction

    //judge when the en_o is enable ,output the useful data
    genvar i,j;
    generate 
    for(i = 1;i<=BWIDTH; i = i + 1)begin
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
                taps[i] <= 0;
            else
                taps[i] <= taps[i-1];
        end
    end
    endgenerate

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            taps[0] <= 0;
        else if(en_i)
            taps[0] <= 1;
        else
            taps[0] <= 0;   
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            en_o <= 0;
        else if(!en_i)
            en_o <= 0;
        else if(en_i && taps[BWIDTH])
            en_o <= 1;
    end

    //the window refresh process one : the other column refresh  
    generate 
    for(i = 0; i < BWIDTH; i = i + 1)begin: out_refresh_loop     
        for(j = 1; j<= BWIDTH; j = j + 1)begin: inner_refresh_loop
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
                cal_block_r[i][(j * DATADEPTH - 1)-:DATADEPTH] <= 0;
            else 
                cal_block_r[i][((j + 1) * DATADEPTH - 1)-:DATADEPTH] <= cal_block_r[i][(j * DATADEPTH - 1)-:DATADEPTH];
        end
      end
    end
    endgenerate
    
    //the window refresh process two : the first column refresh
    //row 0 -> data_in[11:0].....
    generate 
    for(i = 0;i < BWIDTH; i = i + 1)begin
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                cal_block_r[i][DATADEPTH - 1 :0] <= 0;
            end
            else if(en_i)begin
                cal_block_r[i][DATADEPTH - 1 :0] <= data_i[((i + 1) * DATADEPTH - 1)-:DATADEPTH];
            end
            else 
                cal_block_r[i][DATADEPTH - 1 :0] <= 0;
        end
    end
    endgenerate

    wire [DATADEPTH - 1 :0] test1;
    wire [DATADEPTH - 1 :0] test2;

    assign test1 =  cal_block_r[0][5*DATADEPTH - 1 -:DATADEPTH];
    assign test2 =  data_i[(DATADEPTH - 1)-:DATADEPTH];

    //taps the center point for cal
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            center_tap1 <= 0;
            center_tap2 <= 0;
        end
        else begin
            center_tap1 <= cal_block_r[BWIDTH/2][((BWIDTH/2)*DATADEPTH) +: DATADEPTH];
            center_tap2 <= center_tap1;
        end
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
    always@(*)begin
        if(en_o)begin
            if(((center_tap2 == 4095) || (center_tap2 == 0)) && (abs(intp_result,center_tap2) > thre_w))
                    data_o = intp_cliped;
            else 
                    data_o =  center_tap2;
        end
    end

    function [DATADEPTH:0]  abs;
        input [DATADEPTH-1:0] op1;
        input [DATADEPTH-1:0] op2;
        abs = op1 > op2 ? op1 - op2:op2 - op1;
    endfunction
endmodule
