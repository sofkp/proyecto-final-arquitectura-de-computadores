`timescale 1ns / 1ps

    module hazard( input [4:0] Rs1E, Rs2E, 
    input [4:0] RdM, RdW, 
    input RegWriteM, RegWriteW,
    input [4:0] Rs1D, Rs2D, 
    input [4:0] RdE, 
    input ResultSrcE, PCSrcE,  
    input FPRegD, FPRegE, FPRegM, FPRegW,
    output reg [1:0] ForwardAE, ForwardBE,
    output StallF, StallD, FlushE, FlushD);

    wire lwStall;

    //data forwarding
    always @(*) begin
    //foward para a
         if ((Rs1E != 0) && (Rs1E == RdM) && RegWriteM && (FPRegE == FPRegM))
            ForwardAE <= 2'b10;
        else if ((Rs1E != 0) && (Rs1E == RdW) && RegWriteW && (FPRegE == FPRegW))
            ForwardAE <= 2'b01;
         else ForwardAE <= 2'b00;
    //foward para b 
        if ((Rs2E != 0) && (Rs2E == RdM) && RegWriteM && (FPRegE == FPRegM))
            ForwardBE <= 2'b10;
        else if ((Rs2E != 0) && (Rs2E == RdW) && RegWriteW && (FPRegE == FPRegW))
            ForwardBE <= 2'b01;
        else ForwardBE <= 2'b00;
    end
    
    //stalling
    assign lwStall = ((Rs1D == RdE) || (Rs2D == RdE)) && ResultSrcE && (FPRegD == FPRegE);
    assign FlushE = lwStall | PCSrcE;
    assign StallD = lwStall;
    assign StallF = lwStall;
    assign FlushD = PCSrcE;
endmodule