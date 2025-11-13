module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output MemWrite,
                   output [31:0] DataAdr, 
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  localparam WIDTH = 32;
  
  // stage if_id (D)
  wire        RegWriteD, ALUSrcD, MemWriteD, BranchD, JumpD;
  wire [1:0]  ResultSrcD, ImmSrcD;
  wire [2:0]  ALUControlD;
  wire [31:0] PCF, PCPlus4F;
  wire [31:0] PCD, PCPlus4D, InstrD;
  wire [31:0] RD1D, RD2D, ImmExtD;

  // stage id_ex (E)
  wire        RegWriteE, ALUSrcE, MemWriteE, BranchE, JumpE;
  wire [1:0]  ResultSrcE;
  wire [2:0]  ALUControlE;
  wire [31:0] PCE, PCPlus4E, RD1E, RD2E, ImmExtE;
  wire [4:0]  RdE;
  wire [31:0] ALUResultE, PCTargetE;
  wire        ZeroE, PCSrcE;
  

  // stage ex_mem (M)
  wire        RegWriteM, MemWriteM;
  wire [1:0]  ResultSrcM;
  wire [31:0] PCPlus4M, ALUResultM, WriteDataM;
  wire [4:0]  RdM;

  // stage mem_wb (W)
  wire        RegWriteW;
  wire [1:0]  ResultSrcW;
  wire [31:0] PCPlus4W, ALUResultW, ReadDataW;
  wire [4:0]  RdW;
  wire [31:0] ResultW;

  
  //--------------------if_id stage--------------------
  assign PC = PCF;
  
  mux2 #(WIDTH)  pcmux(
    .d0(PCPlus4F), 
    .d1(PCTargetE), 
    .s(PCSrcE), 
    .y(PCNextF)
  ); 

  flopr #(WIDTH) pcreg(
    .clk(clk), 
    .reset(reset), 
    .d(PCNextF), 
    .q(PCF)
  ); 
  
  adder       pcadd4(
    .a(PCF), 
    .b({WIDTH{1'b0}} + 4), // Using WIDTH parameter for constant 4
    .y(PCPlus4F)
  ); 

  if_id if_id_r (.clk(clk), .reset(reset),
    .InstrF(Instr), .PCF(PCF), .PCPlus4F(PCPlus4F), //ins
    .InstrD(InstrD), .PCD(PCD), .PCPlus4D(PCPlus4D) //outs
  );
 
 
 
  //--------------------id_ex stage--------------------

  controller ctrl(
    .op      (InstrD[6:0]),
    .funct3  (InstrD[14:12]),
    .funct7b5(InstrD[30]),
    .ResultSrc(ResultSrcD),
    .MemWrite (MemWriteD),
    .ALUSrc   (ALUSrcD),
    .RegWrite (RegWriteD),
    .Jump     (JumpD),
    .ImmSrc   (ImmSrcD),
    .ALUControl(ALUControlD),
    .Branch   (BranchD)
  );

  regfile     rf(
    .clk(clk), 
    .we3(RegWrite), 
    .a1(InstrD[19:15]), 
    .a2(InstrD[24:20]), 
    .a3(RdW), 
    .wd3(ResultW), 
    .rd1(RD1D), 
    .rd2(RD2D)
  ); 

  extend      ext(
    .instr(InstrD[31:7]), 
    .immsrc(ImmSrcD), 
    .immext(ImmExtD)
  );

  id_ex id_ex_r(.clk(clk), .reset(reset),
    //ins
    .RegWriteD (RegWriteD), .MemWriteD(MemWriteD), .ALUSrcD(ALUSrcD), .BranchD(BranchD), .JumpD(JumpD), .ALUControlD(ALUControlD), .ResultSrcD(ResultSrcD),
    .RD1D(RD1D), .RD2D(RD2D), .ImmExtD(ImmExtD),.PCD(PCD), .PCPlus4D(PCPlus4D), .RdD(InstrD[11:7]),
    //outs
    .RegWriteE (RegWriteE), .MemWriteE(MemWriteE), .ALUSrcE(ALUSrcE), .BranchE(BranchE), .JumpE(JumpE), .ALUControlE(ALUControlE), .ResultSrcE(ResultSrcE),
    .RD1E(RD1E), .RD2E(RD2E), .ImmExtE(ImmExtE), .PCE(PCE), .PCPlus4E(PCPlus4E), .RdE(RdE)
  );
  
  //--------------------ex_mem stage--------------------
  
   // ALU logic
  mux2 #(WIDTH)  srcbmux(
    .d0(RD2E), 
    .d1(ImmExtE), 
    .s(ALUSrcE), 
    .y(SrcBE)
  ); 
  
  wire [31:0] SrcAE = RD1E;

  alu         alu(
    .a(SrcAE), 
    .b(SrcBE), 
    .alucontrol(ALUControlE), 
    .result(ALUResultE), 
    .zero(ZeroE)
  ); 
  
  adder       pcaddbranch(
    .a(PCE), 
    .b(ImmExtE), 
    .y(PCTargetE)
  ); 

  assign PCSrcE = (BranchE & ZeroE) | JumpE;

  ex_mem ex_mem_r(.clk(clk), .reset(reset),
    .ResultSrcE(ResultSrcE), .RegWriteE (RegWriteE), .MemWriteE(MemWriteE), //ins ctr
    .ALUResultE(ALUResultE), .WriteDataE(RD2E),.RdE(RdE), .PCPlus4E(PCPlus4E), //ins datapath

    .ResultSrcM(ResultSrcM), .RegWriteM (RegWriteM), .MemWriteM(MemWriteM),  //outs ctr
    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM), .RdM(RdM), .PCPlus4M(PCPlus4M) //outs datapath
  );

  //--------------------mem_wb stage--------------------

  mem_wb mem_wb_r(.clk(clk), .reset(reset),
    .RegWriteM (RegWriteM), .ResultSrcM(ResultSrcM), //ins ctr
    .ALUResultM(ALUResultM), .ReadDataM(ReadData), .PCPlus4M(PCPlus4M), .RdM(RdM), //ins datapath

    .RegWriteW (RegWriteW), .ResultSrcW(ResultSrcW), //outs ctr
    .ALUResultW(ALUResultW), .ReadDataW(ReadDataW), .PCPlus4W(PCPlus4W), .RdW(RdW)//outs datapath
  );
  
  
  mux3 #(WIDTH)  resultmux(
    .d0(ALUResultW), 
    .d1(ReadDataW), 
    .d2(PCPlus4W), 
    .s(ResultSrcW), 
    .y(ResultW)
  ); 

endmodule
