/*
    Hazard detection unit
    Stall when the operand is being read from memory
*/
module HDU(
    input EX_MemRead,
    input [4:0] EX_RegD,
    input [4:0] ID_Rs,
    input [4:0] ID_Rt,
    output reg Stall
);

always @*
begin
    if(EX_MemRead && (ID_Rs == EX_RegD || EX_RegD == ID_Rt) && EX_RegD != 0)
        Stall = 1;
    else
        Stall = 0;
end

endmodule
