module mux
#(parameter WIDTH = 32)
(
    input sig,
    input [(WIDTH - 1):0] a,
    input [(WIDTH - 1):0] b,
    output [(WIDTH - 1):0] out
    );
    
assign out = sig ? b : a;

endmodule
