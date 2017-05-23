`timescale 1ns / 1ps

module EXHU(
    input rst_n,
    output exc
    );
    
assign exc = ~rst_n;
endmodule
