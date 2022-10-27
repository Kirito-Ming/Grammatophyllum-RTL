/********************************************************************
 *
 *   Author:     Liu jiaming
 *   Date:       2022/10/27
 *   Version:    v1.0
 *   Note:       The simple dual-port sram controller for register image
 *
 *********************************************************************/

module sram_controller #(
    parameter   START_OUT_NUM           =   1024,                           //The condition of transforming IDLE to STORE
                DATA_WIDTH              =   16,                                //Data Width               
                BLOCK_RADIUS            =   5,                               //The radius of Block
                ADDR_WIDTH              =   8,                                //The Width of Address
                IMAGE_WIDTH             =   4032,                             //The width of Image
                IMAGE_HEIGHT            =   3024,                            //The Height of Image
                WIN_RADIUS              =   2                                  //The radius of Window
) (
    clk,
    rstn,
    en_i,
    wraddr_to_sram_o,
    wren_to_sram_o,
    rdaddr_from_sram_o,
    rden_from_sram_o,
    wren_to_process_o
);

    input                                       clk;                        //system clock
    input                                       rstn;                       //reset
    input                                       en_i;                       //module enable
    output reg                                  wren_to_sram_o;             //sync writing enable to sram
    output reg  [ADDR_WIDTH-1           :0]     wraddr_to_sram_o;           //write address to sram
    output reg                                  rden_from_sram_o;           //sync read data from sram
    output reg  [ADDR_WIDTH-1           :0]     rdaddr_from_sram_o;         //read address from sram
    output reg                                  wren_to_process_o;          //sync write enable to process

    reg         [STATE_WIDTH-1          :0]     state_r;          //FSM
    reg         [STATE_WIDTH-1          :0]     next_state_r;     //next_FSM
    reg         [12                     :0]     count;


    parameter STATE_WIDTH           =   3;
    parameter IDLE                  =   3'd0;                           //IDLE, waiting for signal en_i
    parameter STORE                 =   3'd1;                           //STORE, receive the data in SRAM, but the data is not enough to handle
    parameter STORE_PUSH            =   3'd2;                           //STORE_PUSH, receive the data in SRAM While transmit the data to PROCESS
    parameter WAIT_FOR_CAL          =   3'd3;                           //WAIT_FOR_CAL, receive the data in SRAM While waiting for calculating the BlockWindow

    //FSM transform 
    always @(posedge clk or negedge rstn) begin
        if(!rstn)      begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @( *) begin
        case(state) 
            // IDLE:   begin
            //     if()
            //         next_state = IDLE;
            // end
            // STORE:  begin
            //     next_state_r = 
            // end
        endcase
    end

    //count
    always @ (posedge clk or negedge rstn) begin
        // if(!rstn)   begin
        //     count <=
        // end

        case (state)
            
        endcase
    end



endmodule