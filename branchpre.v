`timescale 1ns / 1ps

module branchpre(
    input clk,
    input rst_n,
    input [31:0] Instr,
    input istaken,
    output takebr,
    output takej
    );

wire isbranch;
reg [1:0] state;
reg thatbranch;

parameter BZ = 6'b1;
parameter BEQ = 6'b100;
parameter BNE = 6'b101;
parameter BLEZ = 6'b110;
parameter BGTZ = 6'b111;
parameter J = 6'h2;
    parameter JR = 6'h8;
    parameter JALR = 6'h9;
parameter JAL = 6'h3;

wire [5:0] opcode;

wire [5:0] funct;
assign opcode = Instr[31:26];
assign funct = Instr[5:0];
assign rtype = !opcode;
assign isbranch = (opcode == BZ) || (opcode == BEQ) || (opcode == BNE) || opcode == BLEZ || opcode == BGTZ;
assign isJump =  opcode == JAL || opcode == J;

always @(posedge clk, negedge rst_n)
begin
    if(~rst_n)
    begin
        state <= 0;
        thatbranch <= 0;
    end
    else
    begin
        thatbranch <= isbranch;
        if(thatbranch)
        begin
            if(istaken)
                state <= state == 3 ? state : state + 1;
            else
                state <= state == 0 ? state : state - 1;
         end
    end
end

assign takebr = (isbranch && ($unsigned(state) > 1));
assign takej = isJump;
endmodule
