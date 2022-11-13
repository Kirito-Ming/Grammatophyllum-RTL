module min #(parameter DATADEPTH  = 13
            )
            ( op1,
              op2,
              op3,
              op4,
              min);
    input  [DATADEPTH - 1       :0]              op1;
    input  [DATADEPTH - 1       :0]              op2;
    input  [DATADEPTH - 1       :0]              op3;
    input  [DATADEPTH - 1       :0]              op4;

    output [DATADEPTH - 1       :0]              min;
     
    wire   [DATADEPTH - 1       :0]              comp_result1_w;
    wire   [DATADEPTH - 1       :0]              comp_result2_w;
    
    assign comp_result1_w = op1 > op2?op2:op1;
    assign comp_result2_w = op3 > op4?op4:op3;
    assign min = comp_result1_w > comp_result2_w ? comp_result2_w : comp_result1_w;
endmodule