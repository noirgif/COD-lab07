`timescale 1ns/1ps

module MIPS_TOP(
    input clk,
    input rst_n
);

//---------------------------------
//FETCH
//---------------------------------

Reg rPC(
    .clk(       clk),
    .in(        PCin),
    .out(       PC),//32
    .we(        PCWrite)
);

ALU PCAdd(
    .alu_a(     PC),
    .alu_b(     32'd4),
    .alu_op(    alu_add),
    .alu_out(   PCPlusFour)//32
);

mux PCMux(
    .a(         PCPlusFour),
    .b(         ALUResR),//32
    .sig(       PCSrc),
    .out(       PCin)//32
);


InstMem myInstMem(
    .addr(      PC),
    .out(       Instr)//32
);

IF2ID myIF2ID(
    .clk(       clk),
    .PC(        PC),
    .PCR(       ID_PC),//32
    .Instr(     Instr),
    .InstrR(    ID_Instr),//32
    .IFFlush(   IFFlush),
    .Ctrl(      CtrlIF2ID)
);

//----------------------------------
//DECODE
//----------------------------------

HDU myHDU(//Hazard Detection Unit
      
);

assign ID_ORout = ID_Flush | ID_HDU_ORin;

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
    .A1(        ),
    .A2(        ),
    .A3(        ),
    .in(        WB_MuxOut),
    .A1out(     ID_R1),//32
    .A2out(     ID_R2),//32
    .wea(       WB_RegWrite)
);

Ext SigExt(
    .in(        ID_Instr[15:0]),
    .out(       Sigimm),//32
    .sign(      1'b1)
);

ALU CheckIfEq(
    .alu_a(     ID_R1),
    .alu_b(     ID_R2),
    .alu_op(    alu_sub),
    .Zero(      ID_Eq)
);



//------------------------------------------
//EX
//------------------------------------------

ID2EX myID2EX(
    .clk(       clk),
    .CtrlWB(    ID_CtrlWB),
    .CtrlWBR(   EX_CtrlWB),
    .CtrlM(     ID_CtrlM),
    .CtrlMR(    EX_CtrlMR),
    .CtrlEX(    ID_CtrlEX),
    .CtrlEXR(   EX_CtrlEX),
    .R1(        ID_R1),
    .R2(        ID_R2),
    .R1R(       EX_R1),
    .R2R(       EX_R2),
    .addr1(     ID_AD1),
    .addr2(     ID_AD2),
    .addr1R(    EX_AD1),
    .addr2R(    EX_AD2),
    .5bitwhat
    .5bitwhat
    .r
    .r
);

mux EXFlushMux(
    .a(         EX_CtrlWB),
    .b(         32'b0),
    .sig(       EX_Flush),
    .out(       EX_CtrlWBP)
);

mux MFlushMux(
    .a(         EX_CtrlM),
    .b(         32'b0),
    .sig(       EX_Flush),
    .out(       EX_CtrlMP)
);

EXHU myEXHU(//Exception Handling
);
