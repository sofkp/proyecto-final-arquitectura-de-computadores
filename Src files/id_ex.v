`timescale 1ns / 1ps

module id_ex(input clk, input reset, clr,
input RegWriteD, MemWriteD, ALUSrcD, BranchD, JumpD, input [2:0] ALUControlD, input [1:0] ResultSrcD,
input [31:0] RD1D, RD2D, ImmExtD, PCD, PCPlus4D, input  [4:0] RdD, Rs1D, Rs2D,
output reg RegWriteE, MemWriteE, ALUSrcE, BranchE, JumpE, output reg [2:0] ALUControlE, output reg [1:0] ResultSrcE,
output reg [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E, output reg [4:0] RdE, Rs1E, Rs2E);

    always @(posedge clk) begin
    if (reset) begin
        RegWriteE <= 0;
        MemWriteE <= 0;
        ALUSrcE <= 0;
        BranchE <= 0;
        JumpE <= 0;
        ALUControlE <= 3'b0;
        ResultSrcE  <= 2'b0;
        RD1E <= 0;
        RD2E <= 0;
        ImmExtE <= 0;
        PCE <= 0;
        PCPlus4E <= 0;
        RdE <= 0;
        Rs1E <= 0;
        Rs2E <= 0;
    end else if (clr) begin
        RegWriteE <= 0;
        MemWriteE <= 0;
        ALUSrcE <= 0;
        BranchE <= 0;
        JumpE <= 0;
        ALUControlE <= 3'b0;
        ResultSrcE  <= 2'b0;
        RD1E <= 0;
        RD2E <= 0;
        ImmExtE <= 0;
        PCE <= 0;
        PCPlus4E <= 0;
        RdE <= 0;
        Rs1E <= 0;
        Rs2E <= 0;
    end else begin
        RegWriteE <= RegWriteD;
        MemWriteE <= MemWriteD;
        ALUSrcE <= ALUSrcD;
        BranchE <= BranchD;
        JumpE <= JumpD;
        ALUControlE <= ALUControlD;
        ResultSrcE <= ResultSrcD;
        RD1E <= RD1D;
        RD2E <= RD2D;
        ImmExtE <= ImmExtD;
        PCE  <= PCD;
        PCPlus4E <= PCPlus4D;
        RdE <= RdD;
        Rs1E <= Rs1D;
        Rs2E <= Rs2D;
    end
  end
endmodule
