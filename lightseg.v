module lightseg(
    input clk,
    input rst_n,
    input [31:0] getmem,
    output reg [7:0] seg,
    output reg [3:0] an
);

wire [1:0]bit_disp;
reg [3:0] disp_data;
reg [32:0] clk_count;
wire [4:0] place;
wire word_disp;
assign place = 16 * word_disp + 4 * bit_disp;

assign bit_disp = clk_count[20:19];
assign word_disp = clk_count[27];

always@(posedge clk)
    clk_count <= clk_count + 1;

always@(posedge clk)
	an <= ~(1<<bit_disp);


always @*
begin
    disp_data = getmem[place+:3];
end

always@(posedge clk)
begin
	case(disp_data)
		4'h0: seg = 8'b0000_0011;
		4'h1: seg = 8'b1001_1111;
		4'h2: seg = 8'b0010_0101;
		4'h3: seg = 8'b0000_1101;
		4'h4: seg = 8'b1001_1001;
		4'h5: seg = 8'b0100_1001;
		4'h6: seg = 8'b0100_0001;
		4'h7: seg = 8'b0001_1111;
		4'h8: seg = 8'b0000_0001;
		4'h9: seg = 8'b0000_1001;
		4'd10: seg = 8'b0001_0001;
		4'd11: seg = 8'b1100_0001;
		4'd12: seg = 8'b0110_0011;
		4'd13: seg = 8'b1000_0101;
		4'd14: seg = 8'b0110_0001;
		4'd15: seg = 8'b0111_0001;
		default :
			seg = 8'hff;
	endcase
end


endmodule
