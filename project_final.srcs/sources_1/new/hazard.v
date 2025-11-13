`timescale 1ns / 1ps

module hazard( input [4:0] Rs1E, Rs2E, input [4:0] RdM, RdW, input RegWriteM, RegWriteW,
input [4:0] Rs1D, Rs2D, input [4:0] RdE, input ResultSrcE,
output reg [1:0] ForwardAE, ForwardBE,
output StallF, StallD, FlushE);

    wire lwStall;

    //data forwarding
    always @(*) begin
    //foward para a
        if (((Rs1E == RdM) && RegWriteM) && (Rs1E != 0)) ForwardAE <= 2'b10;
        else if  (((Rs1E == RdW) && RegWriteW) && (Rs1E != 0)) ForwardAE <= 2'b01;
        else ForwardAE <= 2'b00;
    //foward para b 
        if (((Rs2E == RdM) && RegWriteM) && (Rs2E != 0)) ForwardBE <= 2'b10;
        else if  (((Rs2E == RdW) && RegWriteW) && (Rs2E != 0)) ForwardBE <= 2'b01;
        else ForwardBE <= 2'b00;
    end
    
    //stalling
    assign lwStall = ((Rs1D == RdE) || (Rs2D == RdE)) && ResultSrcE ;
    assign FlushE = lwStall;
    assign StallD = lwStall;
    assign StallF = lwStall;
endmodule
