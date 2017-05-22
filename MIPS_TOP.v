`timescale 1ns / 1ps

module MIPS_TOP(
    input clk,
    input rst_n
);

parameter IF = 3'd0;
parameter ID = 3'd1;
parameter EX = 3'd2;
parameter M  = 3'd3;
parameter WB = 3'd4;

//---------------------------------
//FETCH
//---------------------------------

wire [31:0] PCin;
wire [31:0] PC;
wire ID_HDU_Stall;
wire [31:0] PCPlusFour[EX:IF];
wire [31:0] ALUOut[WB:EX];
wire [31:0] Instr[EX:IF];
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
    .b(         ALUOut[WB]),//32
    .sig(       PCSrc),
    .out(       PCin)//32
);

//32bit-wide Mem
InstMem myInstMem(
    .addr(      PC[11:2]),
    .out(       Instr[IF])//32
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
wire [31:0] BAddr, JAddr;
wire [5:0] Opcode[EX:ID], Funct[EX:ID];
wire [4:0] Rs[EX:ID], Rt[EX:ID], Rd[EX:ID];
assign Rs[ID] = Instr[ID][25:21]
assign Rt[ID] = Instr[ID][20:16];
assign Rd[ID] = Instr[ID][15:11];
assign Opcode[ID] = Instr[ID][31:26];
assign Funct[ID] = Instr[ID][5:0];
wire [31:0] ID_R1, ID_R2;
wire Link;
assign Link = BLink | JLink;
assign BAddr = PC[ID] + SigImmShl;
assign JAddr = {PC[ID][31:26], Instr[ID][25:0], 2'b00};

HDU myHDU(//Hazard Detection Unit
    .EX_MemRead(MemRead[EX]),
    .EX_RegD(   RegD[EX]),
    .ID_Rs(     Rs[ID]),
    .ID_Rt(     Rt[ID]),
    .Stall(     ID_HDU_Stall) 
);

branch myBranch(
    .Instr(     Instr[ID]),
    .R1(        R1[ID]),
    .R2(        R2[ID]),
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
    .alu_b(     PC[ID]),
    .alu_op(    ALU_ADD),
    .alu_out(   BranchAddr)
);

reg_file myreg(
    .clk(       clk),
    .A1(        Rs[ID]),
    .A2(        Rt[ID]),
    .A3(        RegD[WB]),
    .in(        MuxOut[WB]),
    .wea(       RegWrite[WB])
);

wire [31:0] SigImm[EX:ID];
Ext SigExt(
    .in(        Instr[ID][15:0]),
    .out(       SigImm),//32
    .sign(      1'b1)
);

Shl myShl2(
    .in(        SigImm),
    .shamt(     32'd2),
    .out(       SigImmShl)
);

//------------------------------------------
//EX
//------------------------------------------

mux EX_WBFlushMux(
    .a(         CtrlWB[EX]),
    .b(         32'b0),
    .sig(       EXFlush),
    .out(       CtrlWBP[EX])
);

mux EX_MFlushMux(
    .a(         CtrlM[EX]),
    .b(         32'b0),
    .sig(       EXFlush),
    .out(       CtrlMP[EX])
);

mux EX_RegDstMux(
    .a(         Rt[EX]),
    .b(         Rd[EX]),
    .c(         5'd31),
    .sig(       {Link[EX], RegDst[EX]}),
    .out(       RegD0[EX])
);


EXHU myEXHU(//Exception Handling
);

mux3 ALUSrcAMux(
    .a(         R1[EX]),
    .b(         WriteData[WB]),
    .c(         Addr[M]),
    .sig(       ForA[EX]),
    .out(       ALUA[EX])//32
);

mux3 ALUSrcBMux(
    .a(         R2[EX]),
    .b(         ALUOut[M]),
    .c(         WriteData[WB][M]),
    .sig(       ForB[EX]),
    .out(       ALUB[EX])//32
);

ALU mainALU(
    .alu_a(     ALUA[EX]),
    .alu_b(     ALUB[EX]),
    .alu_op(    ALUOp[EX]),
    .alu_out(   ALUOut[EX])
);

Forw myFU(//Forward Unit
    .M_RegWrite(    RegWrite[M]),
    .M_RegD(        RegD[M]),
    .WB_RegD(       RegD[WB]),
    .EX_Rs(         Rs[EX]),
    .EX_Rt(         Rt[EX]),
    .EX_ForA(       ForA[EX]),//2
    .EX_ForB(       ForB[EX])//2
);

//----------------------------------
//M(em)
//----------------------------------


DataMem myDataMem(
    .a(         ALUOut[M]),
    .d(         WriteData[M]),
    .clk(       clk),
    .we(        MemWrite[M]),
    .ena(       MemRead[M]),
    .spo(       MemOut[M])
);

//-----------------------------------
//WB
//-----------------------------------

M2WB myM2WB(
    .clk(       clk),
    .Ctrl(      CtrlWB[M]),
    .CtrlR(     CtrlWB[WB])
);

mux WBmux(
    .a(         ALUOut[WB]),
    .b(         MemOut[WB]),
    .sig(       MemtoReg[WB])
    .out(       MuxOut[WB])
);

endmodule
