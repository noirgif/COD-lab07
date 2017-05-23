module ALU(
    input [3:0] alu_op,
    input signed [31:0] alu_a,
    input signed [31:0] alu_b,
    output reg signed [31:0] alu_out,
    output Zero,
    output Overflow,
    output Carry
); 


wire Inv_a, Inv_b;
wire [31:0] a;
wire [31:0] b;
assign AInvert = alu_op[3];
assign BInvert = alu_op[2];
assign Zero = ~|alu_out;
assign a = alu_a ^ {32{AInvert}};
assign b = alu_b ^ {32{BInvert}};

assign CarryIn = alu_op == 4'h6;

always @(*)
begin
    case(alu_op[1:0])
        'd0 : alu_out = a & b;
        'd1 : alu_out = a | b;
        'd2 : alu_out = a + b + CarryIn;
        'd3 : alu_out = a + b + CarryIn < 0;
    endcase
end

assign Overflow = (alu_op == 4'd2) && (alu_out[31] ^ alu_a[31]) & (alu_out[31] ^ alu_b[31]);
assign Carry = (alu_op == 4'd2) && (alu_out);


endmodule
