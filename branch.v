/*
    Branch estimation
    and Branch-and-link descrimination (not implemented here)
*/
module branch(
    input [31:0] Instr,
    input [31:0] R1,
    input [31:0] R2,
    output reg Branch,
    output reg BLink
);
//BGEZ and BLTZ have the same opcode
parameter BZ = 6'b1;
    parameter BGEZ = 4'b1;
    parameter BLTZ = 4'b0;

parameter BEQ = 6'b100;
parameter BNE = 6'b101;
parameter BLEZ = 6'b110;
parameter BGTZ = 6'b111;

wire [5:0] opcode;

wire [3:0] rt;
/* use a temporary variable to avoid repeating Blink every time */
reg _BLink;

assign opcode = Instr[31:26];
assign link = Instr[20];
assign rt = Instr[19:16];

always @*
begin
    case(opcode)
        BZ:
        begin
            case(rt)
                BGEZ:
                begin
                    Branch = ($signed(R1) >= $signed(0));
                    _BLink = Branch & link;
                end
                BLTZ:
                begin
                    Branch = ($signed(R1) < $signed(0));
                    _BLink = Branch & link;
                end
					 default:
					 begin
						  Branch = 0;
						  _BLink = 0;
						  
					 end
            endcase
        end
        BLEZ:
            Branch = ($signed(R1) <= $signed(0));
        BGTZ:
            Branch = ($signed(R1) > $signed(0));
        BEQ:
            Branch = R1 == R2;
        BNE:
            Branch = R1 != R2;
        default:
            Branch = 0;
    endcase
    if(_BLink)
        BLink = 1;
    else
        BLink = 0;
end

endmodule
