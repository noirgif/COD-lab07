module mux3
#(parameter WIDTH=32)
(
    input [1:0] sig,
    input [(WIDTH - 1):0] a,
    input [(WIDTH - 1):0] b,
    input [(WIDTH - 1):0] c,
    output reg [(WIDTH - 1):0] out
);

always @*
begin
    case(sig)
       0: out = a;
       1: out = b;
       default: out = c;
    endcase
end

endmodule
