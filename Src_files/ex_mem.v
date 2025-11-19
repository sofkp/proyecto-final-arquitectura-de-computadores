`timescale 1ns / 1ps

module ex_mem(input clk, input reset, 
input [1:0] ResultSrcE, input RegWriteE, MemWriteE,
input [31:0] ALUResultE, WriteDataE, input [4:0] RdE, input [31:0] PCPlus4E, 
output reg [1:0] ResultSrcM, output reg RegWriteM, MemWriteM,
output reg  [31:0] ALUResultM, WriteDataM, output reg [4:0] RdM, output reg  [31:0] PCPlus4M );


    always @(posedge clk) begin
        if (reset) begin
            RegWriteM <= 0;
            MemWriteM <= 0;
            ResultSrcM <= 2'b0;
            ALUResultM <= 0;
            WriteDataM <= 0;
            RdM <= 0;
            PCPlus4M <= 0;
        end else begin
            RegWriteM <= RegWriteE;
            MemWriteM <= MemWriteE;
            ResultSrcM <= ResultSrcE;
            ALUResultM <= ALUResultE;
            WriteDataM <= WriteDataE;
            RdM <= RdE;
            PCPlus4M <= PCPlus4E;
        end
  end

endmodule