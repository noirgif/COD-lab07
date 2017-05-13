module Ext #(parameter SIZE=16)(
	input sigExt,
	input [SIZE-1:0] imm,
	output [31:0] Ext_out
);


assign Ext_out = {{(32 - SIZE){sigExt & imm[SIZE-1]}}, imm};

endmodule
