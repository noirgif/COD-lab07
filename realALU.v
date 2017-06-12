/*
    the main ALU for the CPU
*/
module realALU(
    input [5:0] opcode,
    input sig,
    input [4:0] shamt,
    input [31:0] ALU_a,
    input [31:0] ALU_b,
    output reg [31:0] ALU_out,
    output reg Overflow
);

parameter NOP = 6'h0;
parameter SRL = 6'h2;
parameter SRA = 6'h3;
    parameter JAL = 6'h3;
parameter SLLV = 6'h4;
parameter SRLV = 6'h6;
parameter JR = 6'h8;
    parameter ADDI = 6'h8;
parameter JALR = 6'h9;
    parameter ADDIU = 6'h9;
    parameter SLTI = 6'ha;
    parameter SLTIU = 6'hb;
    parameter ANDI = 6'hc;
    parameter ORI = 6'hd;
    parameter XORI = 6'he;
    parameter LUI = 6'hf;
parameter ADD = 6'h20;
parameter ADDU = 6'h21;
parameter SUB = 6'h22;
parameter SUBU = 6'h23;
    parameter LW = 6'h23;
parameter AND = 6'h24;
parameter OR = 6'h25;
parameter XOR = 6'h26;
parameter SLT = 6'h2A;
parameter SLTU = 6'h2B;
    parameter SW = 6'h2B;

reg overflow;

always @*
begin
    overflow = 0;
    if(sig)
    begin
        case(opcode)
            NOP: ALU_out = ALU_b << shamt;
            SRL: ALU_out = $unsigned(ALU_b) >> shamt;
            SRA: ALU_out = $signed(ALU_b) >>> shamt;
            SRLV: ALU_out = $unsigned(ALU_b) >> ALU_a;
            SLLV: ALU_out = ALU_b << ALU_a;
            JALR: ALU_out = ALU_b;
            ADD: begin ALU_out = ALU_b + ALU_a; overflow = (ALU_b[31] == ALU_a[31]) & (ALU_a[31] ^ ALU_out[31]);end
            ADDU: ALU_out = ALU_b + ALU_a;
            SUB: begin ALU_out = ALU_a - ALU_b; overflow = (ALU_b[31] ^ ALU_a[31]) & (ALU_a[31] ^ ALU_out[31]);end
            SUBU: ALU_out = ALU_a - ALU_b;
            AND: ALU_out = ALU_a & ALU_b;
            OR: ALU_out = ALU_a | ALU_b;
            SLT: ALU_out = $signed(ALU_a) < $signed(ALU_b);
            SLTU: ALU_out = $unsigned(ALU_a) < $signed(ALU_b);
            XOR: ALU_out = ALU_a ^ ALU_b;
				default: ALU_out = 0;
        endcase
    end
    else
    begin
        case(opcode)
            JAL: ALU_out = ALU_b;
            ADDI: begin ALU_out = ALU_a + ALU_b; overflow = (ALU_b[31] == ALU_a[31]) & (ALU_a[31] ^ ALU_out[31]); end
            ADDIU: ALU_out = ALU_a + ALU_b;
            SLTI: ALU_out = $signed(ALU_a) < $signed(ALU_b);
            SLTIU: ALU_out = $unsigned(ALU_a) < $unsigned(ALU_b);
            ANDI: ALU_out = ALU_a & {16'h0, ALU_b[15:0]};
            ORI: ALU_out = ALU_a & {16'h0, ALU_b[15:0]};
            LUI: ALU_out = ALU_b << 16;
            LW: ALU_out = ALU_a + ALU_b;
            XORI: ALU_out = ALU_a ^ {16'h0, ALU_b[15:0]};
            SW: ALU_out = ALU_a + ALU_b;
				default: ALU_out = 0;
        endcase
    end
    if(overflow)
        Overflow = 1;
    else
        Overflow = 0;
end

endmodule
