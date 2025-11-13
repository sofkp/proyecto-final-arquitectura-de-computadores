`timescale 1ns / 1ps
module mem_wb(input clk, input reset, 
input RegWriteM, input [1:0] ResultSrcM,
input [31:0] ALUResultM, ReadDataM, PCPlus4M, input [4:0] RdM,
output reg RegWriteW, output reg [1:0] ResultSrcW,
output reg [31:0] ALUResultW, ReadDataW, PCPlus4W, output reg [4:0] RdW );
  
  always @(posedge clk) begin
    if (reset) begin
        RegWriteW <= 0;
        ResultSrcW<= 2'b0;
        ALUResultW<= 0;
        ReadDataW<= 0;
        RdW<= 0;
        PCPlus4W<= 0;
    end else begin
        RegWriteW <= RegWriteM;
        ResultSrcW <= ResultSrcM;
        ALUResultW <= ALUResultM;
        ReadDataW <= ReadDataM;
        RdW <= RdM;
        PCPlus4W <= PCPlus4M;
    end
  end
endmodule