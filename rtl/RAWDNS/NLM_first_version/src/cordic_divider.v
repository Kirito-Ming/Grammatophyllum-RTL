/********************************************************************
 *
 *   Author:     Li tianhao
 *   Date:       2022/11/17
 *   Version:    v1.0
 *   Note:       cordic_divider
 *
 *********************************************************************/

module cordic_divider #(parameter  
                        SUM_WIDTH       =  26,
                        DATA_WIDTH      =  12,
                        ITER            =   1
            )
            (
                clk,
                rst_n,
                a_i,
                b_i,
                z_i,
                a_o,
                b_o,
                z_o
            );

    parameter       INIT_Z                  =                   2**(2 * DATA_WIDTH)            ;

    input                                                                   clk                ;
    input                                                                   rst_n              ;
    input                   [SUM_WIDTH                 :0]                  a_i                ;
    input                   [SUM_WIDTH - 1             :0]                  b_i                ;
    input                   [2 * DATA_WIDTH - 1        :0]                  z_i                ;
    output                  [SUM_WIDTH                 :0]                  a_o                ;
    output                  [SUM_WIDTH - 1             :0]                  b_o                ;
    output                  [2 * DATA_WIDTH - 1        :0]                  z_o                ;

    wire        signed      a_i                                                                ;
    reg         signed      a_o                                                                ;
    reg                     b_o                                                                ;
    reg                     z_o                                                                ;

    wire                    [SUM_WIDTH - 1             :0]                 b_shift             ;
    wire                    [2 * DATA_WIDTH - 1        :0]                 z_shift             ;
    wire        signed      [SUM_WIDTH                 :0]                 mux_a   [2:0]       ;
    wire                    [2 * DATA_WIDTH - 1        :0]                 mux_z   [2:0]       ;
    wire        signed      [SUM_WIDTH                 :0]                 add_a               ;
    wire        signed      [SUM_WIDTH                 :0]                 minus_a             ;
    wire                    [2 * DATA_WIDTH - 1        :0]                 add_z               ;
    wire                    [2 * DATA_WIDTH - 1        :0]                 minus_z             ;

    //bi+1 = bi
    always @(posedge clk or negedge rst_n)      begin
        if(!rst_n)
            b_o <= 0;
        else
            b_o <= b_i;
    end

    //ai+1 = ai + di * bi * 2^-i
    assign b_shift = b_i >> ITER;
    assign mux_a[0] = (a_i[SUM_WIDTH] == 1) ? a_i : 0; 
    assign mux_a[1] = (a_i[SUM_WIDTH] == 1) ? 0 : a_i;
    assign mux_a[2] = (a_i[SUM_WIDTH] == 1) ? add_a : minus_a;
    assign add_a = b_shift + mux_a[0];
    assign minus_a = mux_a[1] - b_shift;
    always @(posedge clk or negedge rst_n)      begin
        if(!rst_n)
            a_o <= 0;
        else
            a_o <= mux_a[2];
    end

    //zi+1 = zi - di * 2^-i
    assign z_shift = INIT_Z >> ITER;
    assign mux_z[0] = (a_i[SUM_WIDTH] == 1) ? z_i : 0;
    assign mux_z[1] = (a_i[SUM_WIDTH] == 1) ? 0 : z_i;
    assign mux_z[2] = (a_i[SUM_WIDTH] == 1) ? minus_z : add_z;
    assign add_z = z_shift + mux_z[1];
    assign minus_z = mux_z[0] - z_shift;
    always @(posedge clk or negedge rst_n)      begin
        if(!rst_n)
            z_o <= 0;
        else
            z_o <= mux_z[2];
    end
    
endmodule