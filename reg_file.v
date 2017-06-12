/*
    register file using latch, though flip-flop is better
*/
module reg_file(
	input	clk,
	input	rst_n,
	input[4:0]	A1,
	input[4:0]	A2,
	input[4:0]	A3,
	input[31:0]	in,
	input		wea,
	output	reg [31:0]	A1out,
	output	reg [31:0]	A2out
);

reg	[31:0] reg_file [31:0];
integer i;
always @(posedge clk, negedge rst_n)
begin
	if(~rst_n)
	begin
		for(i = 0;i <= 31;i = i + 1)
			reg_file[i] <= 0;
	end
	else
	begin
		if(wea)
			reg_file[A3] <= in;
	end
end

always @*
begin
    if(A1 != 0)
        A1out = (wea && A1==A3) ? in :reg_file[A1];
    else
        A1out = 0;
    if(A2 != 0)
        A2out = (wea && A2==A3) ? in :reg_file[A2];
    else
        A2out = 0;
end

endmodule
