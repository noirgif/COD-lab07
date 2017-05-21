module Forw(
    input M_RegWrite,
    input [4:0] M_RegD,
    input [4:0] WB_RegD,
    input [4:0] EX_Rs,
    input [4:0] EX_Rt,
    output reg [1:0] EX_ForA,
    output reg [1:0] EX_ForB
);

always @*
begin
    if(M_RegWrite)
    begin
        if(!(|EX_Rs) & (EX_Rs == M_RegD))//M first, then WB, $0 is exception
        begin
        //TO-DO: Forward MemRead in MEM phase
                EX_ForA = 2'b1;
        end
    end
    else
    begin
        if(WB_RegWrite & !(|EX_Rs) & (EX_Rs == WB_RegD))
            EX_ForA = 2'b2;
        else
            EX_ForA = 2'b0;
    end
end

always @*
begin
    if(M_RegWrite & !(|EX_Rt) & (EX_Rt == M_RegD))//M first, then WB, $0 is exception
        EX_ForB = 2'b2;
    else
    begin
        if(WB_RegWrite & !(|EX_Rt) & (EX_Rt == WB_RegD))
            EX_ForB = 2'b1;
        else
            EX_ForB = 2'b0;
    end
end

endmodule

