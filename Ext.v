/*
    Sign Extension (sign = 1)
    Zero Extension (sign = 0)
*/
module Ext #(parameter SIZE=16)(
	input sign,
	input [(SIZE - 1):0] in,
	output reg [31:0] out
);

always @*
begin
    out = {{(32 - SIZE){in[SIZE - 1] & sign}}, in};
end

endmodule
