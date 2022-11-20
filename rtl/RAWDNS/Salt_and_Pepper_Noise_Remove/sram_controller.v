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
                                   through_valid_lt,
                                   through_valid_rd,
                                         full_valid,
                                              pos_y,
                                               en_o
                        );
    parameter ADDR        =      $clog2(IMG_WIDTH);                                               // Addr width of the SRAM 
    parameter STATE_NUM   =                      5;                                               // Num  of the State Num in FSM  
    parameter IDLE        =                 3'b000;                                               // State one: IDLE, the controller is not work
    parameter RW_CORNER   =                 3'b001;                                               // State two: RW_CORNER, when SRAM works,the first write pos is 0 and read pos is IMG_WIDTH -1, one cycle in a 12 bit data and output a column data, before the whole picture read in sram
    parameter RW_TURN     =                 3'b010;                                               // State three: RW_TURNs, when SRAM works in turn, read pos is one cycle later than write pos, one cycle in a 12 bit data and output a column data, before the whole picture read in sram                                          
    parameter R_TURN      =                 3'b011;                                               // State four: R_TURN, after the whole picture read in srams, we need to output the last 2 rows and 2 cols data, the output through in turn (one cycle not in a data but output a column data, sram output not wind)                                                                                     


    input                                                             clk  ;                      // Sysclk                  
    input                                                           rst_n  ;                      // Sysreset                  
    input                                                           vsync  ;                      // FrameStart Signal                  
    input                                                           hsync  ;                      // LineStart Signal                    
    input   [DATADEPTH - 1             : 0]                         data_i ;                      // 12bit data in                     
    output  reg [NUM*DATADEPTH - 1     : 0]                         data_o ;                      // 60bit data out                  
    output  reg [$clog2(NUM) - 1       : 0]                          pos_y ;                      // The pos signal of output column data when LeftTop and RightBottom data through out
    output  reg                                           through_valid_lt ;                      // Through valid: The LeftTop and RightBottom region data through valid signal
    output  reg                                           through_valid_rd ;
    output  reg                                                 full_valid ;                      // Full valid:  valid signal of the center pix of the cal window through out(data fulls the window,at the end of line and start of line)
    output  reg                                                       en_o ;                      // Data_out valid signal                   

    reg     [$clog2(STATE_NUM) - 1    : 0]               state_r, nstate_r ;                      // The state reg
    reg     [NUM - 1                  : 0]                     mem_wr_en_r ;                      // Registers of SRAM array for wr enable signals
    reg     [NUM - 1                  : 0]                     mem_rd_en_r ;                      // Registers of SRAM array for rd enable signals
    reg     [NUM * ADDR - 1           : 0]                   mem_wr_addr_r ;                      // Registers of SRAM array for wr addr variables

    reg     [NUM * ADDR - 1           : 0]                   mem_rd_addr_r ;                      // Registers of SRAM array for rd addr variables
    reg     [NUM * DATADEPTH - 1      : 0]                   mem_wr_data_r ;                      // Registers of SRAM array for wr data variables       
    wire    [NUM * DATADEPTH - 1      : 0]                   mem_rd_data_r ;                      // Registers of SRAM array for rd data variables
    
    reg     [$clog2(IMG_HEIGHT) - 1   : 0]                       count_y_r ;                      // The counter for Row Number Statistic
    reg     [ADDR - 1    : 0]                                    count_x_r ;                      // The counter for Col Number Statistic


    /* sram controller */
        // First stage of FSM: SRAM controller
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            state_r <= IDLE;
        else 
            state_r <= nstate_r;
    end
    
       // Second stage of FSM: SRAM controller
    always@(*)begin
        case(state_r)
            IDLE: begin
                    if(vsync && hsync)   //帧行信号都拉高时，SRAM控制器开始工作
                        nstate_r = RW_CORNER;
                    else
                        nstate_r = IDLE;
            end
            RW_CORNER: begin   // 图像完全存入SRAM前，SRAM读写的边界时刻状态(写下一行首地址并读上一行末地址）
                    if((count_y_r == IMG_HEIGHT) && (count_x_r == 0))  //图像全部存入SRAM，下个状态右下角2行2列数据直接输出
                        nstate_r = R_TURN;
                    else if(state_r != RW_CORNER)  //输入第一个点时打一拍，保持自身在状态RW_CORNER停留一拍
                        nstate_r = RW_CORNER;
                    else                   
                        nstate_r = RW_TURN;    //图像全部写入SRAM前,Corner状态的下一个状态为顺序按行中地址读写
            end
            RW_TURN: begin    //图像完全进入SRAM前,行中按地址顺序读写, 读地址比写地址慢一拍
                    if((count_x_r == IMG_WIDTH - 1)) //写每行末地址时,下个周期为Corner状态,写首地址并读末地址
                        nstate_r = RW_CORNER;
                    else      //图像全部进入SRAM前, 在每行中按顺序读写
                        nstate_r = RW_TURN;  
            end
            R_TURN: begin    //图像完全进入SRAM后,只读不写SRAM，读出右下角两行两列数据，此时count_x_r指向每行读地址，不再是写地址
                    if((count_x_r == 0) && (count_y_r == IMG_HEIGHT)) //输右下角两行两列输出完成，下个状态跳回IDLE
                        nstate_r = IDLE;
                    else
                        nstate_r = R_TURN;  
            end
            default: nstate_r = IDLE;
        endcase
    end

    // count_x_r指向下个周期的写入位置
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            count_x_r <= 0;
        else begin
            case(nstate_r)
                IDLE:          //情况一: SRAM阵列读入前的空闲状态时,行地址计数器置0 /情况二: 右下角最后一个像素输出完毕，行地址计数器置0
                    count_x_r <= 0;
                RW_CORNER:     //情况一：首个像素点读入SRAM时，向地址0写入数据，情况二: 读入行末像素点时，向地址0写入数据
                    count_x_r <= 0;
                R_TURN:begin   //情况一: SRAM完全存入图像数据后的右下角输出状态，此时行列地址计数器都跳变，情况二:图像右下角两行两列按顺序输出
                    if(state_r == RW_CORNER)  //情况一
                       count_x_r <= IMG_WIDTH - NUM/2;
                    else if(count_x_r == IMG_WIDTH - 1)  //情况二边界状态
                       count_x_r <= 0; 
                    else                                 //情况二顺序状态
                       count_x_r <= count_x_r + 1'b1;      
                end
                RW_TURN:begin //将图像正常读入SRAM中,此时按地址顺序正常读写
                    if(count_x_r == IMG_WIDTH - 1)       //边界状态
                       count_x_r <= 0; 
                    else
                       count_x_r <= count_x_r + 1'b1;    //顺序状态
                end
                default: count_x_r <= 0;
            endcase
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            count_y_r <= 0;
        else begin
            case(nstate_r)
                IDLE:      //情况一: SRAM堆未开始工作之前，count_y_r计数器置0， 情况二:右下角图像直接输出完毕
                     count_y_r <= 0;
                R_TURN: begin  //情况一: 从读入至SRAM至跳变到图像右下角输出状态, count_y行指针地址跳变。 情况二: 右下角两行两列图像输出时的顺序行地址跳变逻辑
                     if(state_r == RW_CORNER)
                        count_y_r <= IMG_HEIGHT - 3;
                     else if(count_x_r == IMG_WIDTH - 1)
                        count_y_r <= count_y_r + 1'b1;
                end
                RW_CORNER,RW_TURN: begin //正常图像存入SRAM时的顺序行地址跳变逻辑
                     if(count_x_r == IMG_WIDTH - 1)
                        count_y_r <= count_y_r + 1'b1;
                end
                default: count_y_r <= 0;
            endcase
        end
    end

    /* SRAM控制信号产生逻辑 */
        // 1.SRAM写入使能信号，由于单周期写入单个pixel，因此同一时刻只有一个SRAM写使能
    wire[2:0] write_pos = count_y_r % NUM;  //卷绕写入SRAM
    always@(*)begin
        if(!rst_n)
            mem_wr_en_r = 0;
        else begin
            case(nstate_r)
                IDLE,R_TURN: mem_wr_en_r = 0;   //情况一: SRAM不工作 ,IDLE状态，情况二:右下角直接输出图像状态，SRAM不进行写入
                RW_CORNER,RW_TURN:begin         //由于SRAM的数目有限，采取卷绕写入的方式，如读入前四行图像像素至SRAM阵列堆时，依次向SRAM0-4写入数据;写入第5行数据时，向SRAM0进行卷绕写入
                    mem_wr_en_r = 1 << write_pos;
                end
                default: mem_wr_en_r = 0;
            endcase
        end
    end

        // 2.SRAM读使能产生逻辑，5个SRAM同时读使能，弹出一列数据给Salt and Pepper计算块，但在直接输出左上角和右下角图像块信息时,弹出的列数据只有pos_y位置有效
             //(count_y_r,count_x_r) == (2,2)时弹出左上角第一个像素点,此后直到右下角最后一个像素点读出前SRAM一直使能(对应状态nstate_r == IDLE && state_r == R_TURN)
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            mem_rd_en_r <= 0;
        else begin
            case(nstate_r)
                 IDLE:
                      mem_rd_en_r <= 0; //情况一:SRAM不工作，情况二，右下角最后一个像素点后，进入IDLE状态，SRAM读不使能。
                 RW_CORNER: begin  //
                    if(state_r == IDLE)
                      mem_rd_en_r <= 0;
                 end
                 default: mem_rd_en_r <={NUM{1'b1}};
            endcase
        end
    end

    // 3. SRAM读地址控制逻辑,5个SRAM共用一个地址数据，同一时刻弹出一列数据(5行)，按当前行号卷绕组合。
          //3.1 划窗填满时弹出的一列数据进入划窗计算，左上角和右下角输出状态时弹出的列数据只选取POS_Y位置打拍后直接输出
    genvar i,k;
    generate
    for(i = 0; i < NUM ; i = i + 1)begin:mem_rd_addr_loop
        always@(*)begin
            if(!rst_n)begin
                mem_rd_addr_r[i*ADDR+:ADDR] = 0;    
            end
            else begin
                case(nstate_r)
                    IDLE: begin  //包含两种情况. 情况一:SRAM阵列不使能时, SRAM阵列不读取。 情况二:输出右下角最后一个图像像素点之后，SRAM不进行读取
                        if(state_r == R_TURN)
                            mem_rd_addr_r[i*ADDR+:ADDR] = 0;
                        else
                            mem_rd_addr_r[i*ADDR+:ADDR] = 0;
                    end
                    RW_CORNER: //包含两种情况。情况一:读入首个像素点至SRAM时，此时读不使能，随意读地址均可; 情况二:下个时刻写SRAM下一行首地址并读SRAM上一行末地址
                            mem_rd_addr_r[i*ADDR+:ADDR] = count_x_r - 1'b1;
                    RW_TURN:   //包含两种情况。情况一:此时图像未完全读入SRAM并在行中顺序读写，读取地址为写入地址-1。情况二:图像未完全进入SRAM,向行首写时读行末尾
                        if(state_r == RW_CORNER)
                            mem_rd_addr_r[i*ADDR+:ADDR] = IMG_WIDTH - 1'b1;
                        else
                            mem_rd_addr_r[i*ADDR+:ADDR] = count_x_r - 1'b1;
                    R_TURN:    //此时图像已完全读入SRAM中, count_x_r即为读取地址位置
                        if(state_r == RW_CORNER)
                            mem_rd_addr_r[i*ADDR+:ADDR] = IMG_WIDTH - 1'b1;
                        else
                            mem_rd_addr_r[i*ADDR+:ADDR] = count_x_r;
                    default: mem_rd_addr_r[i*ADDR+:ADDR] = 0;
                endcase
            end
        end
    end
    endgenerate

        //3.2 mem_wr_addr generate, memory写入地址生成电路
    generate
        for(i = 0; i < NUM ; i = i + 1)begin:mem_wr_addr_loop
                always@(*)begin
                    if(!rst_n)
                        mem_wr_addr_r[i * ADDR +: ADDR] = 0;
                    else begin
                        case(nstate_r)
                            IDLE: 
                                mem_wr_addr_r[i * ADDR +: ADDR] = 0; //空闲状态直接输出状态，写入不使能，写地址置为0
                            R_TURN: 
                                mem_wr_addr_r[i * ADDR +: ADDR] = 0; //右下角直接输出状态时,写地址不使能，置为0
                            RW_CORNER: 
                                mem_wr_addr_r[i * ADDR +: ADDR] = count_x_r; //读入图像至SRAM中时,边界情况下，写地址设置为行首
                            RW_TURN:  
                                mem_wr_addr_r[i * ADDR +: ADDR] = count_x_r; //读入图像至SRAM中时，顺序读写情况下，写地址为count_x_r
                            default: mem_wr_addr_r[i * ADDR +: ADDR] = 0;
                        endcase
                    end
                end
        end
    endgenerate

        //3.3 mem_wr_data generate, memory写入数据生成电路
    generate
    for(i = 0; i < NUM ; i = i + 1)begin:mem_wr_data_loop
    //mem_wr_data
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
                mem_wr_data_r[i * DATADEPTH +: DATADEPTH] <= 0;
        else begin
            case(nstate_r)
                IDLE,R_TURN: //SRAM空闲状态及右下角输出状态时，不向其中写入数据，SRAM写入数据无效
                    mem_wr_data_r[i * DATADEPTH +: DATADEPTH] <= 0;
                RW_CORNER,RW_TURN:  //将图像存入SRAM中时,将进入的data_i数据作为5个SRAM的写入数据
                    mem_wr_data_r[i * DATADEPTH +: DATADEPTH] <= data_i;
                default: mem_wr_data_r[i * DATADEPTH +: DATADEPTH] <= 0;
            endcase
        end
    end
    end
    endgenerate



    //3.4 mem_rd_data generate, memory读取数据生成电路
        // SRAM读出数据有效标志电路，当count_y_r > 2或者(count_y_r == 2) && (count_x_r > 0)时，图像左上角的第一个原始像素点输出
        // 当前写入位置位于第二行第二列时，读地址读取第一列数据，输出图像左上角像素值
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            en_o <= 0;
        else begin
            case(nstate_r)
                IDLE: en_o <= 1'b0;
                RW_TURN,RW_CORNER: begin
                    if(((count_y_r == 2) && (count_x_r >= 1)) || (count_y_r > 2))        //if((count_y_r > 2) || ((count_y_r == 2) && (count_x_r > 0)))
                        en_o <= 1'b1;
                    else
                        en_o <= 1'b0;
                end
                R_TURN:
                        en_o <= 1'b1;
                default: en_o <= 1'b0;
            endcase
        end
    end

    //输出数据卷绕，将SRAM中输出列数据转换为正确顺序
    integer j;

    always@(*)begin
        if(!rst_n)
            for(j = 0 ; j < NUM; j = j + 1)begin
                data_o[j * DATADEPTH +: DATADEPTH] = 0; //从sram中读出的数据直接使用组合逻辑输出而不用时序逻辑
            end
        else begin
            case(nstate_r) 
                IDLE : begin
                    if(state_r == R_TURN)
                        data_o = {mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                    mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                    mem_rd_data_r[4 * DATADEPTH +: DATADEPTH]};
                    else
                        data_o = 0;
                end
                RW_TURN, RW_CORNER: begin  // column data out needs to wind
                    if(count_y_r <= 4)begin   //最开头4行数据无需卷绕，当写到第5行第一个像素点时,(count_y,count_x) = (5,0),此时读出数据位置为(4, IMG_WIDTH - 1),用于判断的count_y需要比实际的慢一拍
                            data_o = {mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                                mem_rd_data_r[4 * DATADEPTH +: DATADEPTH]};
                    end
                    else begin
                        if(count_x_r <= 1)begin //count_x_r为写地址，比弹出的数据要快两拍，一拍为读地址延迟，另一拍为sram延迟
                            case(write_pos)
                                    3'd1: data_o = {mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[0 * DATADEPTH +: DATADEPTH]};
                                    3'd2: data_o = {mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[1 * DATADEPTH +: DATADEPTH]};
                                    3'd3: data_o = {mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[2 * DATADEPTH +: DATADEPTH]};
                                    3'd4: data_o = {mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[3 * DATADEPTH +: DATADEPTH]};
                                    3'd0: data_o = {mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[ 1 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[4 * DATADEPTH +: DATADEPTH]};
                                    default: data_o = 0;
                            endcase
                        end
                        else begin
                            case(write_pos)
                                    3'd1: data_o = {mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[1 * DATADEPTH +: DATADEPTH]};
                                    3'd2: data_o = {mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[2 * DATADEPTH +: DATADEPTH]};
                                    3'd3: data_o = {mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[3 * DATADEPTH +: DATADEPTH]};
                                    3'd4: data_o = {mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[4 * DATADEPTH +: DATADEPTH]};
                                    3'd0: data_o = {mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],mem_rd_data_r[ 2 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],mem_rd_data_r[4 * DATADEPTH +: DATADEPTH],
                                                        mem_rd_data_r[0 * DATADEPTH +: DATADEPTH]};
                                    default: data_o = 0;
                            endcase
                        end
                    end
                end
                R_TURN: begin   //最后输出的两行两列不需要卷绕
                        data_o = {mem_rd_data_r[0 * DATADEPTH +: DATADEPTH],mem_rd_data_r[1 * DATADEPTH +: DATADEPTH],
                                    mem_rd_data_r[2 * DATADEPTH +: DATADEPTH],mem_rd_data_r[3 * DATADEPTH +: DATADEPTH],
                                    mem_rd_data_r[4 * DATADEPTH +: DATADEPTH]};
                end   
                default:  data_o = 0;
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

    //产生pos_y信号,pos_y用于左上角图像块直接输出和右下角图像块直接输出,从弹出的column列数据选取需要选择的数据位置
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            pos_y <= 0;
        else begin
            case(nstate_r)
                IDLE: begin
                    if(state_r == R_TURN) //进入IDLE之前的临界状态,此时输出右下角图像像素最后一个点
                         pos_y <= 4;
                    else //空闲状态时,不输出弹出每列数据中的像素点，因此pos_y置为0
                         pos_y <= 0;
                end                  
                RW_CORNER,RW_TURN:begin   //第一个pos_y指定左上角两行两列数据的选取位置,(cur_y,cur_x) = (2,1)点时输出左上角像素点
                                                  //此数据在计算块中需要打拍后进行输出(为了和计算块滑窗填满时的计算逻辑转换形成流水)
                                                  //(pos_y,pos_x) = (2,1)至(pos_y,pos_x) = (3,0)时, pos_y = 0
                                                  //(pos_y,pos_x) = (3,1)至(pos_y,pos_x) = (4,0)时, pos_y = 1
                                                  //(pos_y,pos_x) = (4,1)至(pos_y,pos_x) = (4,2)时, pos_y = 2
                    if(((count_y_r == 2) && (count_x_r > 0))) 
                        pos_y <= 0;
                    else if(((count_y_r == 3) && (count_x_r > 0))) 
                        pos_y <= 1;
                    else if((count_y_r == 4) && (count_x_r > 0))
                        pos_y <= 2;
                end
                R_TURN:begin  //第二个pos_y指定右下角两行两列数据的选取位置
                                   //此时图像完全进入sram中, (cur_y,cur_x)从(1080,1920)跳变至(1077,1918)(此时cur_y跳变至读地址)，pos_y = cur_y,此时数据无需打拍后直接输出
                    if(state_r == RW_CORNER)
                        pos_y <= (IMG_HEIGHT - 1 - NUM/2) % NUM;
                    else
                        pos_y <= count_y_r % NUM;
                end
                default: pos_y <= 0;
            endcase
        end
    end

    //generate the through valid data signal，此信号代表直接through的列信号使能
        //情况一: 当窗口未填满时，左上角最开始两行两列和右下角最末尾两行两列需要直接输出，对应像素为Column列数据中的pos_y位置)
        //情况二: 当窗口填满时，每行最末尾位置的几个像素和每行最初始的几个像素直接使用像素块中间的点代替计算块结果进行输出
    always@(*)begin
        if(!rst_n)
            through_valid_lt = 1'b0;
        else begin
            case(nstate_r)
                IDLE: through_valid_lt = 1'b0;
                RW_CORNER,RW_TURN: begin   //在(count_y_r,count_x_r)范围属于(2,1)至(4,3)中时直接输出进入的一列数据即可
                    if(((count_y_r == 2) && (count_x_r >= 1))  || (count_y_r == 3) || ((count_y_r == 4) && (count_x_r <= 2))) begin
                        through_valid_lt = 1'b1; 
                    end
                    else begin
                        through_valid_lt = 1'b0;
                    end
                end
                
                default: through_valid_lt = 1'b0;
            endcase
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            through_valid_rd <= 1'b0;
        else begin
            case(nstate_r)
                R_TURN:begin
                    if(state_r == RW_CORNER)
                        through_valid_rd <= 1'b0;
                    else
                        through_valid_rd <= 1'b1; 
                end
                default: through_valid_rd <= 1'b0;
            endcase
        end
    end
    //generate the full valid data signa，此信号代表直接输出计算块中心点代替计算结果(对于图像中每行的边界几列数据，左边界几列和右边界几列)
    //(窗口填满时,在图像最右边BWIDTH/2列和最左边BWIDTH/2列直接输出窗口中心值代替)
    //此信号拉高代表进入当前滑窗数据处于列错位状态，应该使用计算块中心值代替
    //运算块中，full_valid拉高时将块中心位置像素值打两拍后代替输出,相当于在运算块输出端口加入MUX选择器
    //椒盐噪声去除模块中，计算流水延迟为2拍，作为标志信号传递给模块SP_CAL_BLOCK后,取块中心值寄存两拍后代替椒盐去除结果并输出
    //考虑当滑窗形成时，至少已经读入了5行数据，并在窗口滑动至图像最右边边界时，此时即将进入数据为图像最左边列(mem读地址为0)，count_x_r = 1
           //，此时计算窗口结果错误，但时序逻辑实际上count_x_r = 1时,其中只能检测到count_x_r = 0,因此边界条件是(count_x_r >= 0) && (count_x_r <= NUM - 1)
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)
            full_valid<=1'b0;
        else begin
            case(nstate_r)
                IDLE,R_TURN: full_valid <= 1'b0;
                RW_TURN,RW_CORNER:begin
                    if((count_y_r > 4) && ((count_x_r <= NUM) && (count_x_r >= 1)))
                        full_valid <= 1'b1; 
                    else
                        full_valid <= 1'b0;
                end
                default: full_valid <= 1'b0;
            endcase
        end
    end
endmodule