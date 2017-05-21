`timescale 1ns / 1ps

module MIPS_TOP(
    input clk,
    input rst_n
);

//---------------------------------
//FETCH
//---------------------------------
wire [31:0] PCin;
wire [31:0] PC;
wire ID_HDU_Stall;
wire [31:0] PCPlusFour;
wire [31:0] WB_ALUOut;
wire [31:0] IF_Instr;
wire [1:0]  IF_Ctrl;
wire [1:0]  PCSrc;

parameter alu_add = 4'd2;

Reg rPC(
    .clk(       clk),
    .in(        PCin),//32
    .out(       PC),//32
    .we(        ~ID_HDU_Stall)
);

ALU PCAdd(
    .alu_a(     PC),
    .alu_b(     32'd4),
    .alu_op(    alu_add),
    .alu_out(   PCPlusFour)//32
);

mux PCMux(
    .a(         PCPlusFour),
    .b(         WB_ALUOut),//32
    .sig(       PCSrc),
    .out(       PCin)//32
);

//32bit-wide Mem
InstMem myInstMem(
    .addr(      PC[11:2]),
    .out(       IF_Instr)//32
);


//----------------------------------
//DECODE
//----------------------------------

IF2ID myIF2ID(
    .clk(       clk),
    .IFFlush(   IFFlush),
    .we(        ~ID_HDU_Stall),
    .Ctrl(      CtrlIF2ID)
);

control my

assign ID_ORout = IDFlush | ID_HDU_Stall;
wire [5:0] ID_Opcode, ID_Funct;
wire [4:0] ID_Rs, ID_Rt, ID_Rd;
assign ID_Rs = ID_Instr[25:21]
assign ID_Rt = ID_Instr[20:16];
assign ID_Rd = ID_Instr[15:11];
assign ID_Opcode = ID_Instr[31:26];
assign ID_Funct = ID_Instr[5:0];
wire [31:0] ID_R1, ID_R2;
wire Link;
assign Link = BLink | JLink;

HDU myHDU(//Hazard Detection Unit
    .EX_MemRead(EX_MemRead),
    .EX_RegD(   EX_RegD),
    .ID_Rs(     ID_Rs),
    .ID_Rt(     ID_Rt),
    .Stall(     ID_HDU_Stall) 
);

branch myBranch(
    .Instr(     ID_Instr),
    .R1(        ID_R1),
    .R2(        ID_R2),
    .Branch(    Branch),
    .BLink(     BLink)
);

mux Dmux(
    .a(         Ctrl_out),//
    .b(         32'd0),
    .sig(       ID_ORout),
    .out(       Ctrl_out1)//
);

ALU BAddrCalc(
    .alu_a(     Shl2_imm),
    .alu_b(     ID_PC),
    .alu_op(    ALU_ADD),
    .alu_out(   BranchAddr)
);

reg_file myreg(
    .clk(       clk),
    .A1(        ID_Rs),
    .A2(        ID_Rt),
    .A3(        WB_RegD),
    .in(        WB_MuxOut),
    .wea(       WB_RegWrite)
);

wire [31:0] SigImm;
Ext SigExt(
    .in(        ID_Instr[15:0]),
    .out(       SigImm),//32
    .sign(      1'b1)
);

//------------------------------------------
//EX
//------------------------------------------

ID2EX myID2EX(
    .clk(       clk),
    .CtrlWB(    ID_CtrlWB),//RD:RegWrite(with Link)
    .CtrlWBR(   EX_CtrlWB),
    .CtrlM(     ID_CtrlM),
    .CtrlMR(    EX_CtrlMR),
    .CtrlEX(    ID_CtrlEX),
    .CtrlEXR(   EX_CtrlEX),
    .SigImm(    SigImm),
    .SigImmR(   EX_SigImm),
    .R1(        ID_R1),
    .R2(        ID_R2),
    .R1R(       EX_R1),
    .R2R(       EX_R2),
    .RegRs(     ID_Rs),
    .RegRt(     ID_Rt),
    .RegRd(     ID_Rd),
    .RegRsR(    EX_Rs),
    .RegRtR(    EX_Rt),
    .RegRdR(    EX_Rd)
);

mux EX_WBFlushMux(
    .a(         EX_CtrlWB),
    .b(         32'b0),
    .sig(       EXFlush),
    .out(       EX_CtrlWBP)
);

mux EX_MFlushMux(
    .a(         EX_CtrlM),
    .b(         32'b0),
    .sig(       EXFlush),
    .out(       EX_CtrlMP)
);

mux EX_RegDstMux(
    .a(         EX_Rt),
    .b(         EX_Rd),
    .c(         5'd31),
    .sig(       {EX_Link, EX_RegDst}),
    .out(       EX_RegD0)
);


EXHU myEXHU(//Exception Handling
);

mux3 ALUSrcAMux(
    .a(         EX_R1),
    .b(         WB_WriteData),
    .c(         M_Addr),
    .sig(       EX_ForA),
    .out(       EX_ALUA)//32
);

mux3 ALUSrcBMux(
    .a(         EX_R2),
    .b(         M_ALUOut),
    .c(         M_WB_WriteData),
    .sig(       EX_ForB),
    .out(       EX_ALUB)//32
);

ALU mainALU(
    .alu_a(     EX_ALUA),
    .alu_b(     EX_ALUB),
    .alu_op(    EX_ALUOp),
    .alu_out(   EX_ALUOut)
);

Forw myFU(//Forward Unit
    .M_RegWrite(    M_RegWrite),
    .M_RegD(        M_RegD),
    .WB_RegD(       WB_RegD),
    .EX_Rs(         EX_Rs),
    .EX_Rt(         EX_Rt),
    .EX_ForA(       EX_ForA),//2
    .EX_ForB(       EX_ForB)//2
);

//----------------------------------
//M(em)
//----------------------------------


DataMem myDataMem(
    .a(         M_ALUOut),
    .d(         M_WriteData),
    .clk(       clk),
    .we(        M_MemWrite),
    .ena(       M_MemRead),
    .spo(       M_MemOut)
);

//-----------------------------------
//WB
//-----------------------------------

M2WB myM2WB(
    .clk(       clk),
    .Ctrl(      M_CtrlWB),
    .CtrlR(     WB_CtrlWB)
);

mux WBmux(
    .a(         WB_ALUOut),
    .b(         WB_MemOut),
    .sig(       WB_MemtoReg)
    .out(       WB_MuxOut)
);

endmodule
