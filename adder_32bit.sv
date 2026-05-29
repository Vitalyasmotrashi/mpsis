`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 23:44:21
// Design Name: 
// Module Name: adder_32bit
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


module adder_32bit (
    input [31:0] a_i,     
    input [31:0] b_i,     
    input carry_i, 
    output [31:0] sum_o,   
    output carry_o  
);

    assign {carry_o, sum_o} = a_i + b_i + carry_i;

endmodule