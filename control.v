module control(
    input [5:0] opcode,
    input [5:0] funct,
    input []    exc,
    input Branch,
    output reg[] IF_Ctrl,//PCSrc
    output reg[] ID_Ctrl,//Jump:JLink:RegDst
    output reg[] EX_Ctrl,
    output reg[] M_Ctrl,
    output reg[] WB_Ctrl
    output IFFlush,
    output IDFlush,
    output EXFlush
);

parameter R_INST = 6'b0;
parameter BZ = 6'b1;
parameter ADDI = 6'b1000;
parameter BEQ = 6'b100;
parameter BLEZ = 6'b110;
parameter BGTZ = 6'b111;
parameter J = 6'b10;
parameter JAL = 6'b11;
parameter LW = 6'b100011;
parameter SW = 6'b101011;
parameter ORI = 6'b001101;

parameter RTYPE = 2'h0;
parameter ITYPE = 2'h1;
parameter JTYPE = 2'h2;
reg [1:0] optype;

always @*
begin
    case(opcode)
        R_INST: optype = RTYPE;
        J: optype = JTYPE;
        default: optype = ITYPE;
    endcase
end

always @*
begin
    if(exc)
        IF_Ctrl = 2'b01;
    else
    begin
        case(optype)
            RTYPE:
                    IF_Ctrl = 'b00;
            ITYPE:
            begin
                if(Branch)
                    IF_Ctrl = 'b01;
                else
                    IF_Ctrl = 'b00;
            end
            JTYPE:
                    IF_Ctrl = 'b01;
        endcase
    end
end

always @*
begin
    case(optype)
        RTYPE:
                ID_Ctrl = 3'b1;
        ITYPE:
                ID_Ctrl = 3'b0;
        JTYPE:
                ID_Ctrl = {opcode[0], 1'b1, 1'bz};
    endcase
end

