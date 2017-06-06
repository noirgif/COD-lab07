module control(
    input [5:0] opcode,
    input [5:0] funct,
    //exception, maybe turned into exception code one day
    input exc,
    input Branch,
    
    input isbr,
    input isj,
    /*
    input wasbr,
    input wasj,
    */
    input mis,
    output reg[1:0] IF_Ctrl,//PCSrc[1:0]
    output reg[2:0] ID_Ctrl,//JLink:Jump:RegDst
/** WB signal = MemtoReg:RegWrite
 *  M  signal = MemRead:MemWrite
 *  EX signal = ALUop(Opcode or Funct)
 */
    output reg [9:0] Ctrl_out,//pack of WB:M:EX control signal
    output IFFlush,
    output IDFlush,
    output EXFlush
);

parameter R_INST = 6'b0;
parameter BZ = 6'b1;
parameter BEQ = 6'b100;
parameter BNE = 6'b101;
parameter BLEZ = 6'b110;
parameter BGTZ = 6'b111;
parameter J = 6'b10;
parameter JAL = 6'b11;
parameter LW = 6'b100011;
parameter SW = 6'b101011;

parameter JR = 6'h8;
parameter JALR = 6'h9;

parameter RTYPE = 2'h0;
parameter ITYPE = 2'h1;
parameter JTYPE = 2'h2;
reg [1:0] optype;

//TO-DO check JR flush???
assign IFFlush = isbr || isj || mis ||  |exc;
assign IDFlush = mis ||  |exc;
assign EXFlush = |exc;

always @*
begin
    case(opcode)
        R_INST: 
            optype = RTYPE;
        J: optype = JTYPE;
        JAL: optype = JTYPE;
        //catch exception(
        default: optype = ITYPE;
    endcase
end

always @*
begin
	case(optype)
			RTYPE:
			//JR and JALR should not be taken into account
					  IF_Ctrl = {1'b0, 1'b0};
			ITYPE:
						IF_Ctrl = {1'b0, Branch};
			JTYPE:
					  IF_Ctrl = 2'b01;
    endcase
    if(exc)
        IF_Ctrl = 2'b10;
end

wire isJALR, isJR;
assign isJALR = funct == 6'h9;
assign isJR = funct[5:1] == 5'h4;

always @*
begin
    case(optype)
        RTYPE:
                ID_Ctrl = {isJALR, isJR, 1'b1};
        ITYPE:
                ID_Ctrl = 3'b0;
        JTYPE:
                ID_Ctrl = {opcode[0], 1'b1, 1'bz};
    endcase
end

wire isLW, isSW, isWR;
assign isLW = opcode == LW;
assign isSW = opcode == SW;
/*RegWrite:
    Almost all operations except
        JR
        J
        SW
        Branch(Without Link)
*/
assign isWR = !(opcode == SW || opcode == BGTZ || opcode == BLEZ || opcode == BEQ || opcode == BNE);

always @*
begin
    case(optype)
        RTYPE:
                Ctrl_out = {1'b0, !(funct == JR), 2'b0, funct};
        ITYPE:
                Ctrl_out = {isLW, isWR, isLW, isSW, opcode};
        JTYPE:
                Ctrl_out = {1'b1, opcode == JAL, 2'b0, opcode};
    endcase
end

endmodule
