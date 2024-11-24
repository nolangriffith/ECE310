`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Nolan Griffith
// 
// Create Date: 11/24/2024
// Design Name: 
// Module Name: delayGen
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


module delayGen(
    input clock,
    input delayEn, //enable hi to get the delay
    output reg delayDone  //the delay has been done (displays handshaking behavior with other features of the zedboard)
    );
    
reg [17:0] counter;    

always @(posedge clock)
begin
    if(delayEn & counter!=200000) //increment to make the delay higher through the counter
        counter <= counter+1;
    else
        counter <= 0;
end

always @(posedge clock)
begin
    if(delayEn & counter==200000)//when it reaches this specific value, then delay is done
        delayDone <= 1'b1;
    else
        delayDone <= 1'b0;
end
    
endmodule
