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
wire [31:0] PCP4[EX:IF];
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
    .alu_out(   PCP4)//32
);

mux PCMux(
    .a(         PCP4),
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

control mycontrol(

);

assign ID_ORout = IDFlush | ID_HDU_Stall;
wire [31:0] BAddr, JAddr;
wire [5:0] Opcode[EX:ID], Funct[EX:ID];
wire [4:0] Rs[EX:ID], Rt[EX:ID], Rd[EX:ID];
assign Rs[ID] = Instr[ID][25:21];
assign Rt[ID] = Instr[ID][20:16];
assign Rd[ID] = Instr[ID][15:11];
assign Opcode[ID] = Instr[ID][31:26];
assign Funct[ID] = Instr[ID][5:0];
wire [31:0] ID_R1, ID_R2;
wire Link;
assign Link = BLink | JLink;
assign BAddr = PCP4[ID] + SigImmShl;
assign JAddr = {PCP4[ID][31:26], Instr[ID][25:0], 2'b00};

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
    .out(       ID_Ctrl_out1)//
);

ALU BAddrCalc(
    .alu_a(     Shl2_imm),
    .alu_b(     PCP4[ID]),
    .alu_op(    4'd2),
    .alu_out(   BranchAddr)
);

reg_file myreg(
    .clk(       clk),
    .A1(        Rs[ID]),
    .A2(        Rt[ID]),
    .A3(        RegD[WB]),
    .in(        WB_MuxOut),
    .A1out(     R1[ID]),
    .A2out(     R2[ID]),
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

mux EXFlushMux0(
    .a(         Ctrl_outWB[EX]),
    .b(         32'b0),
    .sig(       EXFlush),
    .out(       EX_Ctrl_outWB1)
);

mux EXFlushMux1(
    .a(         Ctrl_outM[EX]),
    .b(         32'b0),
    .sig(       EXFlush),
    .out(       EX_Ctrl_outM1)
);

mux EX_RegDstMux(
    .a(         Rt[EX]),
    .b(         Rd[EX]),
    .c(         5'd31),
    .sig(       {Link[EX], RegDst[EX]}),
    .out(       RegD0[EX])
);


EXHU myEXHU(//Exception Handling
    .exc(exc)
);

mux3 ALUSrcAMux(
    .a(         R1[EX]),
    .b(         WB_MuxOut),
    .c(         ALUOut[M]),
    .sig(       ForA),
    .out(       ALUA)//32
);

mux3 ALUSrcBMux(
    .a(         R2[EX]),
    .b(         ALUOut[M]),
    .c(         WriteData[WB][M]),
    .sig(       ForB),
    .out(       ALUB)//32
);

realALU mainALU(
    .ALU_a(     ALUA[EX]),
    .ALU_b(     ALUB[EX]),
    .ALU_op(    (Instr[EX][31:26] ? Instr[EX][31:26] : Instr[EX][5:0])),
    .ALU_out(   ALUOut[EX])
);

Forw myFU(//Forward Unit
    .M_RegWrite(    RegWrite[M]),
    .M_RegD(        RegD[M]),
    .WB_RegD(       RegD[WB]),
    .EX_Rs(         Rs[EX]),
    .EX_Rt(         Rt[EX]),
    .EX_ForA(       ForA),//2
    .EX_ForB(       ForB)//2
);

//----------------------------------
//M(em)
//----------------------------------


DataMem myDataMem(
    .a(         ALUOut[M]),
    .d(         R2[M]),
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
    .Ctrl(      Ctrl_outWB[M]),
    .CtrlR(     Ctrl_outWB[WB])
);

mux WBmux(
    .a(         ALUOut[WB]),
    .b(         MemOut[WB]),
    .sig(       MemtoReg[WB])
    .out(       WB_MuxOut)
);

integer i;
//===================================
//Updating
//===================================
always @(posedge clk)
begin
    if(IFFlush)
        Instr <= 0;
    else
    begin
        if(~ID_HDU_Stall)
        begin
            PC <= PCin;
            PCP4[ID] <= PCP4[IF];
            Instr[ID] <= Instr[IF];
        end
    end

    Ctrl_outEX[EX] <= ID_Ctrl_out1[];
    Ctrl_outM[EX] <= ID_Ctrl_out1[];
    Ctrl_outWB[EX] <= ID_Ctrl_out1[];
    PCP4[EX] <= PCP4[ID];
    Rs[EX] <= Rs[ID];
    Rt[EX] <= Rt[ID];
    Instr[EX] <= Instr[ID];
    R1[EX] <= R1[ID];
    R2[EX] <= R2[ID];
    
    Ctrl_outM[M] <= EX_Ctrl_outM1;
    Ctrl_outWB[M] <= EX_Ctrl_outWB1;
    RegD[M] <= RegD[EX];
    ALUOut[M] <= ALUOut[EX];
    R2[M] <= R2[EX];

    RegD[WB] <= RegD[M];
    Ctrl_outWB[WB] <= Ctrl_outWB[M];
    ALUOut[WB] <= ALUOut[M];
    MemOut[WB] <= MemOut[M];
end
endmodule
