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
wire [31:0] a,b;
assign Zero = ~|alu_out;
assign a = alu_a ^ {32{AInvert}};
assign b = alu_b ^ {32{BInvert}};

assign CarryIn = alu_op == 4'h6;

always @(*)
begin
    case(alu_op)
        4'h0 : alu_res = a & b;
        4'h1 : alu_res = a | b;
        4'h2 : alu_res = a + b + CarryIn;
        4'h3 : alu_res = a + b + CarryIn;
    endcase
end

assign Overflow = (alu_op == 4'd2) && (alu_out[31] ^ alu_a[31]) & (alu_out[31] ^ alu_b[31]);
assign Carry = (alu_op == 4'd2) && (alu_out)


endmodule
