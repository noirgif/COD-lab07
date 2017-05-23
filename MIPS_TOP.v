`timescale 1ns / 1ps

module MIPS_TOP(
    input clk,
    input rst_n
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
reg [31:0]R1[WB:ID];
reg [31:0]R2[WB:ID];
wire exc, IFFlush, IDFlush, EXFlush;
wire [9:0] Ctrl_out;
wire [9:0] Ctrl_out1;
wire [4:0] EX_RegD;
reg EX_Link;
reg [5:0] Ctrl_outEX;
wire [31:0] SigImmShl;
wire [31:0] WB_MuxOut;
wire [31:0] ID_ALUSrcA;

//---------------------------------
//FETCH
//---------------------------------

parameter alu_add = 4'd2;

assign PCSrc = IF_Ctrl;

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
assign JAddr = (Funct[1] == JR) ? ID_R1 : {IF_PCP4[31:26], Instr[1][25:0], 2'b00};
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

branch myBranch(
    .Instr(     Instr[1]),
    .R1(        ID_R1),
    .R2(        ID_R2),
    .Branch(    Branch),
    .BLink(     BLink)
);

mux#(10) Dmux(
    .a(         Ctrl_out),//
    .b(         10'd0),
    .sig(       ID_ORout),
    .out(       Ctrl_out1)//
);


ALU BAddrCalc(
    .alu_a(     SigImmShl),
    .alu_b(     IF_PCP4),
    .alu_op(    4'd2),
    .alu_out(   BAddr)
);

reg_file myreg(
    .clk(       clk),
    .rst_n(     rst_n),
    .A1(        Rs[1]),
    .A2(        Rt[1]),
    .A3(        RegD[WB]),
    .in(        WB_MuxOut),
    .A1out(     ID_R1),
    .A2out(     ID_R2),
    .wea(       RegWrite[WB])
);

Ext SigExt(
    .in(        Instr[1]),
    .sign(      1'b1),
    .out(       ID_SigImm)//32
);

Shl myShl2(
    .in(        ID_SigImm),
    .shamt(     32'd2),
    .out(       SigImmShl)
);

//route PC+4 for jump(branch) and link
mux ALUSrcAMux0(
    .a(         ID_R1),
    //delay slot
    .b(         IF_PCP4),
    .sig(       Link),
    .out(       ID_ALUSrcA)
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
assign EX_RegDst = EX_RType;
assign EX_JType = Opcode[2] == 6'd2 || Opcode[2] == 6'd3;
assign EX_RType = !Opcode[2];
assign EX_IType = !EX_RType && !EX_JType;


wire [1:0] EX_Ctrl_outWB1;
wire [1:0] EX_Ctrl_outM1;
wire [31:0] EX_ALUOut;
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
    .sig(       {!EX_RType & EX_Link, EX_RegDst}),
    .out(       EX_RegD)
);


EXHU myEXHU(//Exception Handling
    .rst_n(rst_n),
    .exc(exc)
);

mux3 ALUSrcAMux(
    .a(         ALUSrcA),
    .b(         WB_MuxOut),
    .c(         ALUOut[3]),
    .sig(       ForA),
    .out(       ALUA)//32
);

//SW needs R2 output, so the mux is put into EX(
mux ALUSrcBMux0(
    .a(         R2[2]),
    .b(         EX_SigImm),
    .sig(       |Instr[2][31:26]),
    .out(       ALUSrcB)
);

mux3 ALUSrcBMux(
    .a(         ALUSrcB),
    .b(         ALUOut[3]),
    .c(         WB_MuxOut),
    .sig(       ForB),
    .out(       ALUB)//32
);

realALU mainALU(
    .ALU_a(     ALUA),
    .ALU_b(     ALUB),
    .opcode(    (EX_RType ? Instr[2][5:0] : Instr[2][31:26])),
    .shamt(     Instr[2][10:6]),
    .sig(       EX_RType),
    .ALU_out(   EX_ALUOut)
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
//M(em)
//----------------------------------

reg [31:0]MemOut[WB:WB];
wire [31:0] M_MemOut;
DataMem myDataMem(
    .a(         ALUOut[3][11:2]),
    .d(         R2[3]),
    .clk(       clk),
    .we(        MemWrite[3]),
    //MemRead should be read enable, not Memory enable, correspoding signal in control.v is suceptible to future change 
    //.ena(       MemRead[3]),
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
        if(IFFlush)
            Instr[1] <= 0;
        else
        begin
            if(~ID_HDU_Stall)
            begin
                PC <= PCin;
                PCP4[1] <= IF_PCP4;
                Instr[1] <= IF_Instr;
            end
        end
        EX_Link <= Link;
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
        R2[3] <= R2[2];
    
        RegD[4] <= RegD[3];
        Ctrl_outWB[4] <= Ctrl_outWB[3];
        ALUOut[4] <= ALUOut[3];
        MemOut[4] <= M_MemOut;
    end
end

endmodule
