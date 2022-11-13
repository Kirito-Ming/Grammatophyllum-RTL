/***************************************************************************
*
*   Author:       Zhang ZhiHan
*   Date:         2022/11/12
*   Version:      v1.0
*   Note:         the controller of sram in the sp noise removal process
*
***************************************************************************/
`timescale 1ns/1ps
module sram_controller #(parameter   NUM = 5,
                                     DATADEPTH = 12,
                                     IMG_WIDTH = 1920,
                                     IMG_HEIGHT = 1080
                        ) 
                        (                       clk,
                                              rst_n,
                                              vsync,
                                              hsync,
                                             data_i,
                                             data_o,
                                      data_o_bypass,
                                               en_o
                        );
    parameter ADDR        =      $clog2(IMG_WIDTH);                                               // Addr width of the SRAM 
    parameter STATE_NUM   =                      5;                                               // Num  of the State Num in FSM  
    parameter IDLE        =                 3'b000;                                               // State one: IDLE, the controller is not work
    parameter STORE       =                 3'b001;                                               // State two: STORE, stores the first four rows in the sram
    parameter SW_TURN     =                 3'b010;                                               // State three: SW_TURN, write and read data in one column 
    parameter SW_CORNER   =                 3'b011;                                               // State four: SW_CORNER, write and read data in two column
    parameter READ        =                 3'b100;                                               // State five: READ, read the data out from sram and not write


    input                                                           clk    ;                      // system clock 
    input                                                           rst_n  ;                      // system reset signal
    input                                                           vsync  ;                      // Frame Sync signal
    input                                                           hsync  ;                      // Line Hsync signal
    input   [DATADEPTH - 1         : 0]                             data_i ;                      // The input data from the hex file ,one cylce one pixel
    output  reg [NUM*DATADEPTH - 1     : 0]                         data_o ;                      // The Column data to the SP noise removal block 
    output  reg [DATADEPTH - 1     : 0]                      data_o_bypass ;                      // The bypass data to the outside channel, not through the sp noise removal module
    output  reg                                                     en_o   ;                      // The output valid signal

    reg     [$clog2(STATE_NUM) - 1    : 0]               state_r, nstate_r ;                      // The state reg
    reg     [NUM - 1                  : 0]                     mem_wr_en_r ;                      // Registers of SRAM array for wr enable signals
    reg     [NUM - 1                  : 0]                     mem_rd_en_r ;                      // Registers of SRAM array for rd enable signals
    reg     [NUM * ADDR - 1           : 0]                   mem_wr_addr_r ;                      // Registers of SRAM array for wr addr variables
    reg     [NUM * ADDR - 1           : 0]                   mem_rd_addr_r ;                      // Registers of SRAM array for rd addr variables
    reg     [NUM * DATADEPTH - 1      : 0]                   mem_wr_data_r ;                      // Registers of SRAM array for wr data variables       
    wire    [NUM * DATADEPTH - 1      : 0]                   mem_rd_data_r ;                      // Registers of SRAM array for rd data variables
    
    reg     [NUM * DATADEPTH - 1      : 0]  mem_rd_data_taps_r [0:NUM/2-1] ;                      // Need Taps to store the mem_rd_data for aligning bypass output data



    //reg     [NUM * DATADEPTH - 1      : 0]                 column_data;

    reg     [$clog2(IMG_HEIGHT) - 1   : 0]                       count_y_r ;                      // The counter for Row Number Statistic
    reg     [ADDR - 1    : 0]                                    count_x_r ;                      // The counter for Col Number Statistic
    reg                                                   hsync_r,hsync_r1 ;                      // The registers for detect the Hsync edge
    wire                                                        hsync_edge ;                      // The Variables for the hsync edge detect
                           
    //  generate the start pulse
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            {hsync_r,hsync_r1} <= 0;
        else
            {hsync_r,hsync_r1} <= {hsync,hsync_r};
    end

    assign hsync_edge = hsync_r && ~hsync_r1;

    //mem controller
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            state_r <= IDLE;
        else 
            state_r <= nstate_r;
    end


    always@(*)begin
        case(state_r)
        IDLE: begin
                if(vsync && hsync_edge)
                    nstate_r = STORE;
                else
                    nstate_r = IDLE;
        end
        STORE: begin
                if((count_x_r == 1) && (count_y_r == NUM - 1))
                    nstate_r = SW_TURN;
                else
                    nstate_r = STORE;
        end
        SW_TURN: begin
                if(count_x_r == IMG_WIDTH - 1)
                    nstate_r = SW_CORNER;
                else if((count_x_r == IMG_WIDTH - 1) && (count_y_r == IMG_HEIGHT - 1))
                    nstate_r = READ;
                else
                    nstate_r = SW_TURN;  
        end
        SW_CORNER: begin
                nstate_r = SW_TURN;
        end
        READ:begin
                if((count_x_r == IMG_WIDTH - 1) && (count_y_r == IMG_HEIGHT - 1 + NUM/2))
                    nstate_r = IDLE;
                else
                    nstate_r = READ;
        end
        default: nstate_r = IDLE;
        endcase
    end


    // pix num count
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            count_x_r <= 0;
        else if(state_r == IDLE)
            count_x_r <= 0;
        else begin
            if(count_x_r == IMG_WIDTH - 1)
                count_x_r <= 0;
            else
                count_x_r <= count_x_r + 1'b1;
        end

    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            count_y_r <= 0;
        else if(state_r == IDLE)
            count_y_r <= 0;
        else begin
            if(count_x_r == IMG_WIDTH - 1)
                count_y_r <= count_y_r + 1'b1;
        end
    end


    // the control logic of the sram group
        // mem_wr_en
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            mem_wr_en_r <= 0;
        else if((nstate_r == IDLE) || (nstate_r == READ))
            mem_wr_en_r <= 0;
        else begin
            if(count_y_r <= 4)
                mem_wr_en_r <= (1 << count_y_r);
            else
                mem_wr_en_r <= (1 << (count_y_r - 5)) ;
        end
    end

        // mem_rd_en
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            mem_rd_en_r <= 0;
        else if((nstate_r == IDLE) || (nstate_r == STORE))
            mem_rd_en_r <= 0;
        else if(nstate_r == READ)
            mem_rd_en_r <= 1<<(count_y_r -IMG_HEIGHT + NUM/2);
        else 
            mem_rd_en_r <= {NUM{1'b1}};
    end

       
    genvar i,k;
    generate
    for(i = 0;i < NUM ; i = i + 1)begin:mem_rd_addr_loop
        //mem_rd_addr
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                mem_rd_addr_r[i*ADDR+:ADDR] <= 0;    
            end
            else begin
                if(count_x_r == 0)
                    mem_rd_addr_r[i*ADDR+:ADDR] <= IMG_WIDTH - 1'b1;
                else
                    mem_rd_addr_r[i*ADDR+:ADDR] <= count_x_r - 1'b1;
            end
        end

        //mem_wr_addr
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
                mem_wr_addr_r[i * ADDR +: ADDR] <= 0;
            else begin
                if(count_x_r == 0)
                    mem_wr_addr_r[i * ADDR +: ADDR] <= IMG_WIDTH - 1;
                else
                    mem_wr_addr_r[i * ADDR +: ADDR] <= count_x_r - 1;
            end
        end

        //mem_wr_data
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
               mem_wr_data_r[i * DATADEPTH +: DATADEPTH] <= 0;
            else
               mem_wr_data_r[i * DATADEPTH +: DATADEPTH] <= data_i;
        end
    end
    endgenerate

    //mem rd data out 
    integer j;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            en_o <= 0;
        else begin
            case(state_r)
                SW_TURN, SW_CORNER,READ: en_o <= 1'b1;
                default: en_o <= 1'b0;
            endcase
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            for(j = 0 ; j < NUM; j = j + 1)begin
                data_o[j * DATADEPTH +: DATADEPTH] <= 0;
            end
        else if(en_o) begin
            case(state_r) 
                SW_TURN, SW_CORNER: begin
                    case(count_y_r % NUM)
                            3'd1: data_o <= {mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[1 * DATADEPTH +: DATADEPTH]};
                            3'd2: data_o <= {mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[2 * DATADEPTH +: DATADEPTH]};
                            3'd3: data_o <= {mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[3 * DATADEPTH +: DATADEPTH]};
                            3'd4: data_o <= {mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[4 * DATADEPTH +: DATADEPTH]};
                            3'd0: data_o <= {mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[0 * DATADEPTH +: DATADEPTH]};
                            default: data_o <= 0;
                    endcase
                end   
                default:  data_o <= 0;
            endcase
        end
        else 
            data_o <= 0;
    end
   

   // bypass mem data out
      // taps for the mem_rd_data_r, mem_rd_data_taps_r [0:NUM/2-1] ;  
    generate
    for (i = 1 ; i < NUM/2 ; i = i + 1)begin
        for (k = 1; k < NUM ; k = k + 1)begin
            always@(posedge clk or negedge rst_n)begin
                if(!rst_n)
                     mem_rd_data_taps_r[i][(k*DATADEPTH - 1)-:DATADEPTH] <= 0;
                else
                     mem_rd_data_taps_r[i][(k*DATADEPTH - 1)-:DATADEPTH] <= mem_rd_data_taps_r[i - 1][(k*DATADEPTH - 1)-:DATADEPTH];
            end
        end
    end


    for (k = 1; k < NUM ; k = k + 1)begin
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)
                 mem_rd_data_taps_r[0][(k*DATADEPTH - 1)-:DATADEPTH] <= 0;
            else  
                 mem_rd_data_taps_r[0][(k*DATADEPTH - 1)-:DATADEPTH] <= mem_rd_data_r[(k*DATADEPTH - 1)-:DATADEPTH];
        end
    end
    endgenerate


    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            data_o_bypass <= 1'b0;
        else begin
            case(state_r)
                READ: case(count_y_r % NUM)
                          3'd0: begin
                                if(count_x_r < NUM/2)
                                    data_o_bypass <= mem_rd_data_taps_r[1][2 * DATADEPTH +: DATADEPTH];  
                                else  
                                    data_o_bypass <= mem_rd_data_taps_r[1][3 * DATADEPTH +: DATADEPTH];                                    
                          end
                          3'd1: begin
                                if(count_x_r < NUM/2)
                                    data_o_bypass <= mem_rd_data_taps_r[1][3 * DATADEPTH +: DATADEPTH];  
                                else  
                                    data_o_bypass <= mem_rd_data_taps_r[1][4 * DATADEPTH +: DATADEPTH];  
                          end
                          3'd2: begin
                                if(count_x_r < NUM/2)
                                    data_o_bypass <= mem_rd_data_taps_r[1][4 * DATADEPTH +: DATADEPTH];
                          end
                          default: data_o_bypass <= 0;
                      endcase
                default: data_o_bypass <= 0;
            endcase
        end
    end

    //inst the sram group
    generate 
        for(i = 0;i < NUM ; i = i + 1)begin: mem_inst_loop
            sram #(.ADDR_WIDTH(ADDR),.DATA_WIDTH(DATADEPTH)) inst
            (.rddata_o(mem_rd_data_r[i * DATADEPTH +: DATADEPTH]),.wraddr_i(mem_wr_addr_r[i * ADDR +: ADDR]),
            .rdaddr_i(mem_rd_addr_r[i * ADDR +: ADDR]),.wrdata_i(mem_wr_data_r[i * DATADEPTH +: DATADEPTH]),
            .wren_i(mem_wr_en_r[i]),.rden_i(mem_rd_en_r[i]),.wrclk(clk),.rdclk(clk));
        end
    endgenerate
endmodule