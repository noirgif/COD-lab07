`timescale 1ns / 1ps

module MIPS_TOP(
    input clk,
    input rst_n
);

parameter IF = 0;
parameter ID = 1;
parameter EX = 2;
parameter M  = 3;
parameter WB = 4;

wire [31:0] PCin;
wire [31:0] BJAddr;
reg [31:0] PC;
wire ID_HDU_Stall;
reg [31:0] PCP4[EX:ID];
reg [31:0] ALUOut[WB:EX];
reg [31:0] Instr[EX:IF];
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
reg [4:0]RegD[WB:EX];
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
reg [31:0] SigImm[EX:ID];

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

mux PCMux(
    .a(         PCP4[IF]),
    .b(         BJAddr),
    .c(         32'h80000180),
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


parameter JAL = 6'h3;
parameter JR = 6'h8;

assign ID_ORout = IDFlush | ID_HDU_Stall;
assign Opcode[ID] = Instr[ID][31:26];
assign Opcode[EX] = Instr[EX][31:26];
assign Funct[ID] = Instr[ID][5:0];
assign Funct[EX] = Instr[EX][5:0];
assign JLink = ID_Ctrl[2];
assign Link = BLink | JLink;
assign JAddr = (Funct[ID] == JR) ? ID_R1 : {{32'd4 + PCP4[ID]}[31:26], Instr[ID][25:0], 2'b00};
assign Jump = ID_Ctrl[1];
assign BJAddr = Branch ? BAddr : JAddr;

always @*
begin
    Rs[ID] = Instr[ID][25:21];
    Rt[ID] = Instr[ID][20:16];
    Rd[ID] = Instr[ID][15:11];
end

generate
genvar i;
        for(i = EX; i <= M; i = i + 1)
        begin :gen1
            always @*
            begin
                MemRead[i] = Ctrl_outM[i][1];
                MemWrite[i] = Ctrl_outM[i][0];
            end
        end
endgenerate

generate
genvar j;
        for(j = EX; j <= WB; j = j + 1)
        begin :gen2
            always @*
            begin
                RegWrite[j] = Ctrl_outWB[j][0];
                MemtoReg[j] = Ctrl_outWB[j][1];
            end
         end
endgenerate

control myControl(
    .opcode(    Opcode[ID]),
    .funct(     Funct[ID]),
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
    .EX_MemRead(MemRead[EX]),
    .EX_RegD(   EX_RegD),
    .ID_Rs(     Rs[ID]),
    .ID_Rt(     Rt[ID]),
    .Stall(     ID_HDU_Stall) 
);

branch myBranch(
    .Instr(     Instr[ID]),
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
    .alu_a(     SigImmShl),
    .alu_b(     PCP4[IF]),
    .alu_op(    4'd2),
    .alu_out(   BAddr)
);

reg_file myreg(
    .clk(       clk),
    .A1(        Rs[ID]),
    .A2(        Rt[ID]),
    .A3(        RegD[WB]),
    .in(        WB_MuxOut),
    .A1out(     ID_R1),
    .A2out(     ID_R2),
    .wea(       RegWrite[WB])
);

Ext SigExt(
    .in(        Instr[ID][15:0]),
    .out(       SigImm[ID]),//32
    .sign(      1'b1)
);

Shl myShl2(
    .in(        SigImm[ID]),
    .shamt(     32'd2),
    .out(       SigImmShl)
);

//route PC+4 for jump(branch) and link
mux ALUSrcAMux0(
    .a(         ID_R1),
    //delay slot
    .b(         PCP4[IF]),
    .sig(       Link),
    .out(       ID_ALUSrcA)
);

//------------------------------------------
//EX
//------------------------------------------
reg [31:0] ALUSrcA;
reg [31:0] ALUSrcB;
wire EX_IType, EX_JType, EX_RType;
wire EX_RegDst;
wire [1:0] ForA, ForB;
wire [31:0] ALUA, ALUB;
reg [31:0] EX_SigImm;
assign EX_RegDst = EX_RType;
assign EX_JType = Opcode[EX] == 6'd2 || Opcode[EX] == 6'd3;
assign EX_RType = !Opcode[EX];
assign EX_IType = !EX_RType && !EX_JType;


wire [1:0] EX_Ctrl_outWB1;
wire [1:0] EX_Ctrl_outM1;
wire [31:0] EX_ALUOut;
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
    //jal(J-Type) use $31 but jalr(R-Type) use $rd
    .sig(       {!EX_RType & EX_Link, EX_RegDst}),
    .out(       EX_RegD)
);


EXHU myEXHU(//Exception Handling
    .exc(exc)
);

mux3 ALUSrcAMux(
    .a(         ALUSrcA),
    .b(         WB_MuxOut),
    .c(         ALUOut[M]),
    .sig(       ForA),
    .out(       ALUA)//32
);

//SW needs R2 output, so the mux is put into EX(
mux ALUSrcBMux0(
    .a(         R2[EX]),
    .b(         EX_SigImm),
    .sig(       |Instr[EX][31:26]),
    .out(       ALUSrcB)
);

mux3 ALUSrcBMux(
    .a(         ALUSrcB),
    .b(         ALUOut[M]),
    .c(         WB_MuxOut),
    .sig(       ForB),
    .out(       ALUB)//32
);

realALU mainALU(
    .ALU_a(     ALUA),
    .ALU_b(     ALUB),
    .ALU_op(    (EX_RType ? Instr[EX][5:0] : Instr[EX][31:26])),
    .sig(       EX_RType),
    .ALU_out(   EX_ALUOut)
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

reg MemOut[WB:M];
DataMem myDataMem(
    .a(         ALUOut[M]),
    .d(         R2[M]),
    .clk(       clk),
    .we(        MemWrite[M]),
    //MemRead should be read enable, not Memory enable, correspoding signal in control.v is suceptible to future change 
    .ena(       MemRead[M]),
    .spo(       MemOut[M])
);

//-----------------------------------
//WB
//-----------------------------------

mux WBmux(
    .a(         ALUOut[WB]),
    .b(         MemOut[WB]),
    .sig(       MemtoReg[WB]),
    .out(       WB_MuxOut)
);

//==================================================
//Updating sequence, too many wires to make a module
//==================================================
always @(posedge clk)
begin
    if(IFFlush)
        Instr[ID] <= 0;
    else
    begin
        if(~ID_HDU_Stall)
        begin
            PC <= PCin;
            PCP4[ID] <= IF_PCP4;
            Instr[ID] <= IF_Instr;
        end
    end

    EX_Link <= Link;
    ALUSrcA <= ID_ALUSrcA;
    SigImm[EX] <= SigImm[ID];
    Ctrl_outEX <= Ctrl_out1[5:0];
    Ctrl_outM[EX] <= Ctrl_out1[7:6];
    Ctrl_outWB[EX] <= Ctrl_out1[9:8];
    PCP4[EX] <= PCP4[ID];
    Rs[EX] <= Instr[ID][25:21];
    Rt[EX] <= Instr[ID][20:16];
    Instr[EX] <= Instr[ID];
    R1[EX] <= ID_R1;
    R2[EX] <= ID_R2;
    
    Ctrl_outM[M] <= EX_Ctrl_outM1;
    Ctrl_outWB[M] <= EX_Ctrl_outWB1;
    RegD[M] <= RegD[EX];
    ALUOut[M] <= EX_ALUOut;
    R2[M] <= R2[EX];

    RegD[WB] <= RegD[M];
    Ctrl_outWB[WB] <= Ctrl_outWB[M];
    ALUOut[WB] <= ALUOut[M];
    MemOut[WB] <= MemOut[M];
end

endmodule
