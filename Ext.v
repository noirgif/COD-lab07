module Ext #(parameter SIZE=16)(
	input sign,
	input [(SIZE - 1):0] in,
	output reg [31:0] out
);

always @*
begin
    $display("in: %d out: %d\n", in, out);
    out = {{(32 - SIZE){in[SIZE - 1] & sign}}, in};
end

endmodule
