`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nolan Griffith
// 
// Create Date: 11/24/2024
// Design Name: 
// Module Name: oledControl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module oledControl(
input  clock, //100MHz clock
input  reset, 
//oled interface
output wire oled_spi_clk, //clock
output wire oled_spi_data, //data
output reg oled_vdd, //vdd
output reg oled_vbat, //vbat
output reg oled_reset_n, //active low signal for reset
output reg oled_dc_n, //choose between command and data through SPI interface
//
input [6:0] sendData,
input       sendDataValid,
output reg  sendDone
    );
    
reg [4:0] state;
reg [4:0] nextState;
reg startDelay;
reg [7:0] spiData;
reg spiLoadData;
wire delayDone;
wire spiDone;
reg [1:0] currPage;
wire [63:0] charBitMap;
reg [7:0] columnAddr;
reg [3:0] byteCounter;

    //define states
localparam  IDLE  = 'd0,
            DELAY = 'd1,
            INIT  = 'd2,
            RESET = 'd3,
            CHRG_PUMP = 'd4,
            CHRG_PUMP1 = 'd5,
            WAIT_SPI = 'd6,
            PRE_CHRG = 'd7,
            PRE_CHRG1 = 'd8,
            VBAT_ON = 'd9,
            CONTRAST = 'd10,
            CONTRAST1 = 'd11,
            SEG_REMAP = 'd12,
            SCAN_DIR = 'd13,
            COM_PIN = 'd14,
            COM_PIN1 = 'd15,
            DISPLAY_ON = 'd16,
            FULL_DISPLAY = 'd17,
            DONE = 'd18,
            PAGE_ADDR = 'd19,
            PAGE_ADDR1 = 'd20,
            PAGE_ADDR2 = 'd21,
            COLUMN_ADDR = 'd22,
            SEND_DATA = 'd23;

//instantiate system to power up through state machine
always @(posedge clock)
begin
    if(reset)
    begin
        state <= IDLE;
        nextState <= IDLE;
        oled_vdd <= 1'b1; //from data sheet, power supply for logic, high at beginning
        oled_vbat <= 1'b1;
        oled_reset_n <= 1'b1;
        oled_dc_n <= 1'b1;
        startDelay <= 1'b0;
        spiData <= 8'd0;
        spiLoadData <= 1'b0;
        currPage <= 0;
        sendDone <= 0;
        columnAddr <= 0;
    end
    else
    begin
        case(state)
            IDLE:begin //initialize the OLED controller by beginning the OLED Initialization Sequence
                oled_vbat <= 1'b1;
                oled_reset_n <= 1'b1;
                oled_dc_n <= 1'b0;
                oled_vdd <= 1'b0; //if you want to apply power, it has to be active low
                state <= DELAY;
                nextState <= INIT;
            end
            DELAY:begin//wait for 2ms
                startDelay <= 1'b1;
                if(delayDone)
                begin
                    state <= nextState; //used as a flag to determine where do go once we go to the delay state
                    startDelay <= 1'b0;
                end
            end
            INIT:begin //use loaddata as an enabler and use data_in
                spiData <= 'hAE;
                spiLoadData <= 1'b1;
                if(spiDone)
                begin
                    spiLoadData <= 1'b0;
                    oled_reset_n <= 1'b0;
                    state <= DELAY;
                    nextState <= RESET; //remove the reset
                end
            end
            RESET:begin
                 oled_reset_n <= 1'b1; //remove reset
                 state <= DELAY; //from delay then we go to the charge pump declaration
                 nextState <= CHRG_PUMP;
            end
            CHRG_PUMP:begin
                spiData <= 'h8D;
                spiLoadData <= 1'b1;
                if(spiDone)
                begin
                    spiLoadData <= 1'b0; //spi controller is running at 10 mHZ vs OLED controller at 100 mHz 
                    state <= WAIT_SPI; //special state needed until SPI controller sees the loadData signal
                    nextState <= CHRG_PUMP1;
                end
            end
            WAIT_SPI:begin
                if(!spiDone)
                begin
                    state <= nextState;
                end
            end
            CHRG_PUMP1:begin
                spiData <= 'h14;
                spiLoadData <= 1'b1;
                if(spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= PRE_CHRG;
                end
            end
            PRE_CHRG:begin //configure precharge the same way as charge pump 1
                spiData <= 'hD9;
                spiLoadData <= 1'b1;
                if(spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= PRE_CHRG1;
                end
            end
            PRE_CHRG1:begin
               spiData <= 'hF1;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= VBAT_ON;
               end
            end            
            VBAT_ON:begin
                oled_vbat <= 1'b0;
                state <= DELAY;
                nextState <= CONTRAST;
            end
            CONTRAST:begin
               spiData <= 'h81;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= CONTRAST1;
               end
            end  
            CONTRAST1:begin //set the contrast
               spiData <= 'hFF;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= SEG_REMAP;
               end
            end            
            SEG_REMAP:begin
               spiData <= 'hA0;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= SCAN_DIR;
               end
            end 
            SCAN_DIR:begin
               spiData <= 'hC0;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= COM_PIN;
               end
            end 
            COM_PIN:begin
               spiData <= 'hDA;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= COM_PIN1;
               end
            end
            COM_PIN1:begin
               spiData <= 'h00;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= DISPLAY_ON;
               end
            end  
            DISPLAY_ON:begin
               spiData <= 'hAF;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= PAGE_ADDR;//FULL_DISPLAY;
               end
            end //done with initialization, test with FULL_DISPLAY with setting A5 and setting next state to DONE.
            PAGE_ADDR:begin
                spiData <= 'h22;
                spiLoadData <= 1'b1;
                oled_dc_n <= 1'b0;
                if(spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= PAGE_ADDR1;
                end
            end
            PAGE_ADDR1:begin //specify the page address
                spiData <= currPage; //start the page address
                spiLoadData <= 1'b1;
                if(spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    currPage <= currPage+1;
                    nextState <= PAGE_ADDR2;
                end
            end  
            PAGE_ADDR2:begin
                spiData <= currPage;//start page address for next page (currPage+1)
                spiLoadData <= 1'b1;
                if(spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= COLUMN_ADDR;
                end
            end              
            COLUMN_ADDR:begin //specifies which column to display 
                spiData <= 'h10; //want to start the data from column 1
                spiLoadData <= 1'b1; 
                if(spiDone)
                begin
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    nextState <= DONE;
                end
            end            
            /*FULL_DISPLAY:begin
               spiData <= 'hA5;
               spiLoadData <= 1'b1;
               if(spiDone)
               begin
                   spiLoadData <= 1'b0;
                   state <= WAIT_SPI;
                   nextState <= DONE;
               end
            end*/ 
            DONE:begin
                sendDone <= 1'b0; //the date will stop sending, the other module will see it in the next clock if one module is high
                if(sendDataValid & columnAddr != 128 & !sendDone) //handshaking process saying it will allow to send data 
                    state <= SEND_DATA;
                    byteCounter <= 8;
                end
            else if(sendDataValid & columnAddr == 128 & !sendDone) 
                begin
                begin
                    state <= PAGE_ADDR; // put in a switch page command
                    columnAddr <= 0;
                    byteCounter <= 8;
                end
            end   
            SEND_DATA:begin //give the data that displays on the OLED column by column
                spiData <= charBitMap[(byteCounter*8-1)-:8]; //send 8 bytes to send one character, we send 1 byte at a time
                //if lower index is less than upper index by 1 (requirement of OLED)
                spiLoadData <= 1'b1;
                oled_dc_n <= 1'b1;
                if(spiDone)
                begin
                    columnAddr <= columnAddr + 1;
                    spiLoadData <= 1'b0;
                    state <= WAIT_SPI;
                    if(byteCounter != 1)
                    begin
                        byteCounter <= byteCounter - 1;
                        nextState <= SEND_DATA; //come back to the same state
                    end
                    else
                    begin
                        nextState <= DONE;
                        sendDone <= 1'b1;
                    end
                end
            end                   
        endcase
    end
end
 
//instantiate delayGen module with the OLED controller 
delayGen DG(
    .clock(clock),
    .delayEn(startDelay),
    .delayDone(delayDone)
    ); 
    
    //instantiate SPI controller inside OLED Controller
spiControl SC(
    .clock(clock), //On-board Zynq clock (100 MHz)
    .reset(reset),
    .data_in(spiData),
    .load_data(spiLoadData), //Signal indicates new data for transmission
    .done_send(spiDone),//Signal indicates data has been sent over spi interface
    .spi_clock(oled_spi_clk),//10MHz max
    .spi_data(oled_spi_data)
    );    
    
    
charROM CR(
    .addr(sendData),
    .data(charBitMap) 
 );
    
endmodule
