`timescale 1ns / 1ps

module MIPS_TOP(
    input clk,
    input rst_n,
    output [7:0] seg,
    output [3:0] an
);

parameter IF = 0;
parameter ID = 1;
parameter EX = 2;
parameter M = 3;
parameter WB = 4;

wire [31:0] PCin;
wire [31:0] BJAddr;
reg [31:0] PC;
wire ID_HDU_Stall;
reg [31:0] PCP4[EX:ID];
reg [31:0] ALUOut[WB:M];
reg [31:0] Instr[EX:ID];
wire [1:0]  IF_Ctrl;
wire [1:0]  PCSrc;
wire [31:0] IF_PCP4;
wire [31:0] IF_Instr;
wire ID_ORout;

wire [31:0] BAddr, JAddr;
wire [5:0] Opcode[EX:ID], Funct[EX:ID];
reg [4:0] Rs[EX:ID], Rt[EX:ID], Rd[EX:ID];

wire [31:0] ID_R1, ID_R2;
wire [2:0] ID_Ctrl;
wire Link, JLink, BLink;

wire Branch, Jump;

reg MemRead[M:EX];
reg MemWrite[M:EX];
reg [1:0]Ctrl_outM[M:EX];
reg [4:0]RegD[WB:M];
reg RegWrite[WB:EX];
reg MemtoReg[WB:EX];
reg [1:0]Ctrl_outWB[WB:EX];
reg [31:0]R1[EX:EX];
reg [31:0]R2[M:EX];
wire exc, IFFlush, IDFlush, EXFlush;
wire [9:0] Ctrl_out;
wire [9:0] Ctrl_out1;
wire [4:0] EX_RegD;
reg [5:0] Ctrl_outEX;
wire [31:0] SigImmShl;
wire [31:0] WB_MuxOut;
wire [31:0] ID_ALUSrcA;

//---------------------------------
//FETCH
//---------------------------------

parameter alu_add = 4'd2;
wire [31:0] ID_JAddr, ID_BAddr;
reg wasj, wasbr;
wire mis;
assign mis = (wasbr ^ Branch) | (wasj ^ Jump);
assign PCSrc = IF_Ctrl;
assign ID_JAddr = {IF_PCP4[31:26], Instr[1][25:0], 2'b00};

ALU PCAdd(
    .alu_a(     PC),
    .alu_b(     32'd4),
    .alu_op(    alu_add),
    .alu_out(   IF_PCP4)//32
);

mux3 PCMux(
    .a(         IF_PCP4),
    .b(         BJAddr),
    .c(         32'h80000180),
    .sig(       PCSrc),
    .out(       PCin)//32
);

//32bit-wide Mem
InstMem myInstMem(
    .a(      PC[11:2]),
    .spo(       IF_Instr)//32
);


//----------------------------------
//DECODE
//----------------------------------


parameter JAL = 6'h3;
parameter JR = 6'h8;

wire [31:0]ID_SigImm;

assign ID_ORout = IDFlush | ID_HDU_Stall;
assign Opcode[1] = Instr[1][31:26];
assign Opcode[2] = Instr[2][31:26];
assign Funct[1] = Instr[1][5:0];
assign Funct[2] = Instr[2][5:0];
assign JLink = ID_Ctrl[2];
assign Link = BLink | JLink;
assign JAddr = (Funct[1] == JR) ? ID_R1 : {PCP4[1][31:26], Instr[1][25:0], 2'b00};
assign Jump = ID_Ctrl[1];
assign BJAddr = Branch ? BAddr : JAddr;

integer i,j;
always @*
begin
    Rs[1] = Instr[1][25:21];
    Rt[1] = Instr[1][20:16];
    Rd[1] = Instr[1][15:11];
end   
  
always @*
begin
    for(i = EX; i <= M; i = i + 1)
    begin
        MemRead[i] = Ctrl_outM[i][1];
        MemWrite[i] = Ctrl_outM[i][0];
    end
end



always @*
begin
    for(j = EX; j <= WB; j = j + 1)
    begin
        RegWrite[j] = Ctrl_outWB[j][0];
        MemtoReg[j] = Ctrl_outWB[j][1];
    end
end


control myControl(
    .opcode(    Opcode[1]),
    .funct(     Funct[1]),
    .isbr(      takebr),
    .isj(       takej),
    .wasbr(     wasbr),
    .wasj(      wasj),  
    .exc(       exc),
    .Branch(    Branch),
    .IF_Ctrl(   IF_Ctrl),
    .ID_Ctrl(   ID_Ctrl),
    .Ctrl_out(  Ctrl_out),
    .IFFlush(   IFFlush),
    .IDFlush(   IDFlush),
    .EXFlush(   EXFlush)
);

HDU myHDU(//Hazard Detection Unit
    .EX_MemRead(MemRead[2]),
    .EX_RegD(   EX_RegD),
    .ID_Rs(     Rs[1]),
    .ID_Rt(     Rt[1]),
    .Stall(     ID_HDU_Stall) 
);

mux#(10) Dmux(
    .a(         Ctrl_out),//
    .b(         10'd0),
    .sig(       ID_ORout),
    .out(       Ctrl_out1)//
);


reg_file myreg(
    .clk(       clk),
    .rst_n(     rst_n),
    .A1(        Rs[1]),
    .A2(        Rt[1]),
    .A3(        RegD[4]),
    .in(        WB_MuxOut),
    .A1out(     ID_R1),
    .A2out(     ID_R2),
    .wea(       RegWrite[4])
);

Ext SigExt(
    .in(        Instr[1]),
    .sign(      1'b1),
    .out(       ID_SigImm)//32
);



//route PC+4 for jump(branch) and link
mux ALUSrcAMux0(
    .a(         ID_R1),
    //delay slot
    .b(         IF_PCP4),
    .sig(       Branch | Jump),
    .out(       ID_ALUSrcA)
);


branchpre mybrp(
    .clk(       clk),
    .rst_n(     rst_n),
    .Instr(     IF_Instr),
    .istaken(   Branch || Jump),
    .takebr(    takebr),
    .takej(     takej)
);

always @(posedge clk, negedge rst_n)
begin
    if(~rst_n)
    begin
        wasj <= 0;
        wasbr <= 0;
    end
    else
    begin
        wasj <= ~mis & takej;
        wasbr <= ~mis & takebr;
    end
end

ALU ID_BAddrCalc(
    .alu_a(     $signed(IF_Instr[15:0])),
    .alu_b(     PCP4[1]),
    .alu_op(    4'd2),
    .alu_out(   ID_BAddr)
);

//------------------------------------------
//EX
//------------------------------------------
reg [31:0] ALUSrcA;
wire [31:0] ALUSrcB;
wire EX_IType, EX_JType, EX_RType;
wire EX_RegDst;
wire [1:0] ForA, ForB;
wire [31:0] ALUA, ALUB;
reg [31:0] EX_SigImm;
wire [31:0] pre_ALUOut;
assign EX_RegDst = EX_RType;
assign EX_JType = Opcode[2] == 6'd2 || Opcode[2] == 6'd3;
assign EX_RType = !Opcode[2];
assign EX_IType = !EX_RType && !EX_JType;


wire [1:0] EX_Ctrl_outWB1;
wire [1:0] EX_Ctrl_outM1;
wire [31:0] EX_ALUOut;
wire [31:0] M_MemOut;
mux#(2) EXFlushMux0(
    .a(         Ctrl_outWB[2]),
    .b(         2'b0),
    .sig(       EXFlush),
    .out(       EX_Ctrl_outWB1)
);

mux#(2) EXFlushMux1(
    .a(         Ctrl_outM[2]),
    .b(         2'b0),
    .sig(       EXFlush),
    .out(       EX_Ctrl_outM1)
);

mux3#(5) EX_RegDstMux(
    .a(         Rt[2]),
    .b(         Rd[2]),
    .c(         5'd31),
    //jal(J-Type) use $31 but jalr(R-Type) use $rd
    .sig(       {!EX_RType & Link, EX_RegDst}),
    .out(       EX_RegD)
);

Shl myShl2(
    .in(        EX_SigImm),
    .shamt(     32'd2),
    .out(       SigImmShl)
);

EXHU myEXHU(//Exception Handling
    .rst_n(rst_n),
    .exc(exc)
);

branch myBranch(
    .Instr(     Instr[2]),
    .R1(        ALUA),
    .R2(        ALUB),
    .Branch(    Branch),
    .BLink(     BLink)
);

//Beware! Using PC in ID to calculate
ALU EX_BAddrCalc(
    .alu_a(     SigImmShl),
    .alu_b(     PCP4[2]),
    .alu_op(    4'd2),
    .alu_out(   BAddr)
);

mux3 ALUSrcAMux(
    .a(         ALUSrcA),
    .b(         M_MemOut),
    .c(         ALUOut[3]),
    .sig(       ForA),
    .out(       ALUA)//32
);

//SW needs R2 output, so the mux is put into EX(
mux ALUSrcBMux0(
    .a(         ALUSrcB),
    .b(         EX_SigImm),
    .sig(       |Instr[2][31:26]),
    .out(       ALUB)
);

mux3 ALUSrcBMux(
    .a(         R2[2]),
    .b(         ALUOut[3]),
    .c(         WB_MuxOut),
    .sig(       ForB),
    .out(       ALUSrcB)//32
);

realALU mainALU(
    .ALU_a(     ALUA),
    .ALU_b(     ALUB),
    .opcode(    (EX_RType ? Instr[2][5:0] : Instr[2][31:26])),
    .shamt(     Instr[2][10:6]),
    .sig(       EX_RType),
    .ALU_out(   pre_ALUOut)
);

mux aluReschange(
    .a(         pre_ALUOut),
    .b(         PCP4[2]),
    .sig(       Link),
    .out(       EX_ALUOut)
);

Forw myFU(//Forward Unit
    .M_RegWrite(    RegWrite[3]),
    .M_RegD(        RegD[3]),
    .WB_RegWrite(   RegWrite[4]),
    .WB_RegD(       RegD[4]),
    .EX_Rs(         Rs[2]),
    .EX_Rt(         Rt[2]),
    .EX_ForA(       ForA),//2
    .EX_ForB(       ForB)//2
);

//----------------------------------
//M(em)r
//----------------------------------

reg [31:0]MemOut[WB:WB];
wire [7:0]switch;
wire [31:0]getmem;
DataMem myDataMem(
    .a(         ALUOut[3][11:2]),
    .d(         R2[3]),
    .clk(       clk),
    .we(        MemWrite[3]),
    //MemRead should be read enable, not Memory enable, correspoding signal in control.v is suceptible to future change 
    //.ena(       MemRead[3]),
    .dpra(      switch),
    .dpo(       getmem),
    .spo(       M_MemOut)
);

//-----------------------------------
//WB
//-----------------------------------

mux WBmux(
    .a(         ALUOut[4]),
    .b(         MemOut[4]),
    .sig(       MemtoReg[4]),
    .out(       WB_MuxOut)
);

//------------------------------------
//misc
//------------------------------------

lightseg mylight(
    .clk(       clk),
    .rst_n(     rst_n),
    .getmem(    getmem),//31:0
    .seg(      seg),//7:0
    .an(       an)//3:0
);

//==================================================
//Updating sequence, too many wires to make a module
//==================================================
always @(posedge clk, negedge rst_n)
begin
    if(~rst_n)
    begin
        PC <= 0;
        Instr[1] <= 0;
        PCP4[1] <= 0;
    end
    else
    begin
        if(IFFlush | mis)
            Instr[1] <= 0;
        else
        begin
            if(~ID_HDU_Stall)
            begin
                Instr[1] <= IF_Instr;
            end
        end
        if(mis)
            PC <= (Branch | Jump)? BJAddr : PCP4[ID];
        else
        if(takebr)
            PC <= ID_BAddr;
        else
        if(takej)
            PC <= ID_JAddr;
        else
        begin
            if(~ID_HDU_Stall)
                PC <= PCin;
        end
        PCP4[1] <= IF_PCP4;
        ALUSrcA <= ID_ALUSrcA;
        EX_SigImm <= ID_SigImm;
        Ctrl_outEX <= Ctrl_out1[5:0];
        Ctrl_outM[2] <= Ctrl_out1[7:6];
        Ctrl_outWB[2] <= Ctrl_out1[9:8];
        PCP4[2] <= PCP4[1];
        Rs[2] <= Instr[1][25:21];
        Rt[2] <= Instr[1][20:16];
        Instr[2] <= Instr[1];
        R1[2] <= ID_R1;
        R2[2] <= ID_R2;
        Rd[2] <= Rd[1];
        
        Ctrl_outM[3] <= EX_Ctrl_outM1;
        Ctrl_outWB[3] <= EX_Ctrl_outWB1;
        RegD[3] <= EX_RegD;
        ALUOut[3] <= EX_ALUOut;
        R2[3] <= ALUSrcB;
    
        RegD[4] <= RegD[3];
        Ctrl_outWB[4] <= Ctrl_outWB[3];
        ALUOut[4] <= ALUOut[3];
        MemOut[4] <= M_MemOut;
    end
end

endmodule
