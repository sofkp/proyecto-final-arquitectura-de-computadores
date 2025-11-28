`timescale 1ns / 1ps

module controller(input  [6:0] op,
                  input  [2:0] funct3,
                  input  [6:0] funct7,
                  output [1:0] ResultSrc, 
                  output MemWrite, ALUSrc, RegWrite, Jump, Branch,
                  output [2:0] ImmSrc, 
                  output [2:0] ALUControl,
                  output FP, FPlw, FPsw, FP16);
  
  wire [1:0] ALUOp; 
  
  maindec md(
    .op(op), 
    .ResultSrc(ResultSrc), 
    .MemWrite(MemWrite), 
    .Branch(Branch),
    .ALUSrc(ALUSrc), 
    .RegWrite(RegWrite), 
    .Jump(Jump), 
    .ImmSrc(ImmSrc), 
    .ALUOp(ALUOp),
    .FP(FP), .FPlw(FPlw), .FPsw(FPsw)
  ); 

  aludec  ad(
    .opb5(op[5]), 
    .funct3(funct3), 
    .funct7b5(funct7[5]), 
    .ALUOp(ALUOp), 
    .ALUControl(ALUControl)
  ); 
  
  assign FP = (op == 7'b1010011) || (op == 7'b0000111) || (op == 7'b0100111);
  assign FPlw  = (op == 7'b0000111); //flw
  assign FPsw = (op == 7'b0100111); //fsw  
  
  assign FP16 = (op == 7'b1010011) && (funct7[1:0] == 2'b10);


endmodule
