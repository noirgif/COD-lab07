`timescale 1ns / 1ps

module EXHU(
    input rst_n,
    input Overflow,
    output reg [1:0] exc
    );

always @*
begin
    if(rst_n)
        exc = 0;
    else
        if(Overflow)
            exc = 2'b01;
end
endmodule
