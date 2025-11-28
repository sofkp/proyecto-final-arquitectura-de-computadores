module riscvsingle(input  clk, reset,
                   output [31:0] PC,
                   input  [31:0] Instr,
                   output MemWrite,
                   output [31:0] DataAdr, 
                   output [31:0] WriteData,
                   input  [31:0] ReadData);

  localparam WIDTH = 32;
  
  wire [31:0] PCNextF;
  
  // stage if_id (D)
  wire RegWriteD, ALUSrcD, MemWriteD, BranchD, JumpD, FPD, FPlwD, FPswD;
  wire [1:0] ResultSrcD;
  wire [2:0] ALUControlD, ImmSrcD;
  wire [31:0] PCF, PCPlus4F, PCD, PCPlus4D, InstrD, RD1D, RD2D, ImmExtD;

  // stage id_ex (E)
  wire RegWriteE, ALUSrcE, MemWriteE, BranchE, JumpE, FPE, FPlwE, FPswE;
  wire [1:0] ResultSrcE;
  wire [2:0] ALUControlE;
  wire [31:0] PCE, PCPlus4E, RD1E, RD2E, ImmExtE, ALUResultE, PCTargetE, SrcAE, SrcBE, prevB;
  wire [4:0] RdE, Rs1E, Rs2E;
  wire ZeroE, PCSrcE;
  

  // stage ex_mem (M)
  wire RegWriteM, MemWriteM, FPlwM, FPswM;
  wire [1:0] ResultSrcM;
  wire [31:0] PCPlus4M, ALUResultM, WriteDataM;
  wire [4:0] RdM;

  // stage mem_wb (W)
  wire RegWriteW;
  wire [1:0] ResultSrcW;
  wire [31:0] PCPlus4W, ALUResultW, ReadDataW;
  wire [4:0] RdW;
  wire [31:0] ResultW;
  
  //hazar unit 
  wire [1:0] ForwardAE, ForwardBE;
  wire StallF, StallD, FlushE, FlushD;
  
  wire [4:0] Rs1D, Rs2D;
  
  wire[31:0] InstrE,InstrM,InstrW;
  assign Rs1D = InstrD[19:15];
  assign Rs2D = InstrD[24:20];
  
  wire FPRegD, FPRegE, FPRegM, FPRegW;
  assign FPRegD = FPD;
  assign FPRegE = FPE; 
  assign FPRegM = (InstrM[6:0] == 7'b1010011) || (InstrM[6:0] == 7'b0000111); //fp alu y lw
  assign FPRegW = (InstrW[6:0] == 7'b1010011) || (InstrW[6:0] == 7'b0000111); 

  
  hazard hazard_unit(.Rs1E(Rs1E), .Rs2E(Rs2E), .RdM(RdM), .RdW(RdW), .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
  .Rs1D(Rs1D), .Rs2D(Rs2D), .RdE(RdE), .ResultSrcE(ResultSrcE[0]), .PCSrcE(PCSrcE),
  .FPRegD(FPRegD), .FPRegE(FPRegE), .FPRegM(FPRegM), .FPRegW(FPRegW),
  .ForwardAE(ForwardAE), .ForwardBE(ForwardBE), .StallF(StallF), .StallD(StallD), .FlushE(FlushE), .FlushD(FlushD)
  );

  
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
    .en(~StallF),
    .d(PCNextF), 
    .q(PCF)
  ); 
  
  adder       pcadd4(
    .a(PCF), 
    .b({WIDTH{1'b0}} + 4), // Using WIDTH parameter for constant 4
    .y(PCPlus4F)
  ); 

  if_id if_id_r (.clk(clk), .reset(reset), .en(~StallD), .FlushD(FlushD), 
    .InstrF(Instr), .PCF(PCF), .PCPlus4F(PCPlus4F), //ins
    .InstrD(InstrD), .PCD(PCD), .PCPlus4D(PCPlus4D) //outs
  );
 
 
 
  //--------------------id_ex stage--------------------
  wire FP16D, FP16E;
  controller ctrl(
    .op      (InstrD[6:0]),
    .funct3  (InstrD[14:12]),
    .funct7  (InstrD[31:25]),
    .ResultSrc(ResultSrcD),
    .MemWrite (MemWriteD),
    .ALUSrc   (ALUSrcD),
    .RegWrite (RegWriteD),
    .Jump     (JumpD),
    .ImmSrc   (ImmSrcD),
    .ALUControl(ALUControlD),
    .Branch   (BranchD),
    .FP(FPD),.FPlw(FPlwD),.FPsw(FPswD), .FP16(FP16D)
  );
  
  wire FPAluD, FPAluE;
  assign FPAluD = (InstrD[6:0] == 7'b1010011);  
    
  wire [31:0] RD1_intD, RD2_intD, RD1_fpD,  RD2_fpD;
  
  wire RegWriteIntW, RegWriteFPW;

  assign RegWriteFPW  = RegWriteW & FPRegW;
  assign RegWriteIntW = RegWriteW & ~FPRegW;
  
  int_regfile     irf(
    .clk(clk), 
    .we3(RegWriteIntW), 
    .a1(Rs1D), 
    .a2(Rs2D), 
    .a3(RdW), 
    .wd3(ResultW), 
    .rd1(RD1_intD), 
    .rd2(RD2_intD)
  ); 
  
  fp_regfile     frf(
    .clk(clk), 
    .we3(RegWriteFPW), 
    .a1(Rs1D), 
    .a2(Rs2D), 
    .a3(RdW),
    .wd3(ResultW), 
    .rd1(RD1_fpD), 
    .rd2(RD2_fpD)
  ); 
  
  assign RD1D = FPRegD ? RD1_fpD : RD1_intD;
  assign RD2D = FPRegD ? RD2_fpD : RD2_intD;

  extend      ext(
    .instr(InstrD[31:7]), 
    .immsrc(ImmSrcD), 
    .immext(ImmExtD)
  );

  id_ex id_ex_r(.clk(clk), .reset(reset), .clr(FlushE),
    //ins
    .RegWriteD (RegWriteD), .MemWriteD(MemWriteD), .ALUSrcD(ALUSrcD), .BranchD(BranchD),
    .JumpD(JumpD), .ALUControlD(ALUControlD), .ResultSrcD(ResultSrcD),
    .RD1D(RD1D), .RD2D(RD2D), .ImmExtD(ImmExtD),.PCD(PCD), .PCPlus4D(PCPlus4D), 
    .RdD(InstrD[11:7]), .Rs1D(Rs1D), .Rs2D(Rs2D),
    .InstrD(InstrD),.InstrE(InstrE), .FPD(FPD), .FPlwD(FPlwD), .FPswD(FPswD),
    .FP16D(FP16D), .FPAluD(FPAluD),
    //outs
    .RegWriteE (RegWriteE), .MemWriteE(MemWriteE), .ALUSrcE(ALUSrcE), .BranchE(BranchE),
    .JumpE(JumpE), .ALUControlE(ALUControlE), .ResultSrcE(ResultSrcE),
    .RD1E(RD1E), .RD2E(RD2E), .ImmExtE(ImmExtE), .PCE(PCE), .PCPlus4E(PCPlus4E), .RdE(RdE), 
    .Rs1E(Rs1E), .Rs2E(Rs2E), .FPE(FPE), .FPlwE(FPlwE), .FPswE(FPswE),
    .FP16E(FP16E), .FPAluE(FPAluE) 
  );
  
  //--------------------ex_mem stage--------------------
  
   // ALU logic
  mux3  #(WIDTH) bmux3(.d0(RD2E), .d1(ResultW), .d2(ALUResultM), .s(ForwardBE), .y(prevB));
  mux2 #(WIDTH)  srcbmux(
    .d0(prevB), 
    .d1(ImmExtE), 
    .s(ALUSrcE), 
    .y(SrcBE)
  ); 
  
  mux3 #(WIDTH) srcamux (.d0(RD1E), .d1(ResultW), .d2(ALUResultM), .s(ForwardAE), .y(SrcAE));
  
  wire [31:0] ALUResultE_normal;
  
  alu         alu(
    .a(SrcAE), 
    .b(SrcBE), 
    .alucontrol(ALUControlE), 
    .result(ALUResultE_normal), 
    .zero(ZeroE)
  ); 
  
  wire [1:0] FPOp;
  assign FPOp = (InstrE[31:27] == 5'b00000) ? 2'b00 : // fadd
                (InstrE[31:27] == 5'b00001) ? 2'b01 : // fsub
                (InstrE[31:27] == 5'b00010) ? 2'b10 : // fmul
                (InstrE[31:27] == 5'b00011) ? 2'b11 : // fdiv
                                       2'b00;  // default

  
  wire [31:0] FPResultE;
  wire FPValidE;
  wire [4:0] FPFlagsE;

  falu falu_unit(.clk(clk),.rst(reset),.start(FPAluE),.op_a(SrcAE),.op_b(SrcBE),
    .op_code(FPOp),.mode_fp(~FP16E),.round_mode(1'b0),.result(FPResultE),.valid_out(FPValidE),
    .flags(FPFlagsE) );
  
  
  wire [31:0] ALUResult_preFP = FPAluE ? FPResultE : ALUResultE_normal;
  wire is_lui = (InstrE[6:0] == 7'b0110111);
  assign ALUResultE = is_lui ? ImmExtE : ALUResult_preFP;


  adder       pcaddbranch(
    .a(PCE), 
    .b(ImmExtE), 
    .y(PCTargetE)
  ); 

  assign PCSrcE = (BranchE & ZeroE) | JumpE;

  ex_mem ex_mem_r(.clk(clk), .reset(reset), .FPlwE(FPlwE),.FPswE(FPswE),
    .ResultSrcE(ResultSrcE), .RegWriteE (RegWriteE), .MemWriteE(MemWriteE), //ins ctr
    .ALUResultE(ALUResultE), .WriteDataE(prevB),.RdE(RdE), .PCPlus4E(PCPlus4E), //ins datapath
    .InstrE(InstrE),.InstrM(InstrM),
    .FPlwM(FPlwM),.FPswM(FPswM),
    .ResultSrcM(ResultSrcM), .RegWriteM (RegWriteM), .MemWriteM(MemWriteM),  //outs ctr
    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM), .RdM(RdM), .PCPlus4M(PCPlus4M) //outs datapath
  );

  //--------------------mem_wb stage--------------------

  mem_wb mem_wb_r(.clk(clk), .reset(reset),
    .RegWriteM (RegWriteM), .ResultSrcM(ResultSrcM), //ins ctr
    .ALUResultM(ALUResultM), .ReadDataM(ReadData), .PCPlus4M(PCPlus4M), .RdM(RdM), //ins datapath
    .InstrM(InstrM),.InstrW(InstrW),
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
  
  assign DataAdr = ALUResultM;
  assign WriteData = WriteDataM;
  assign MemWrite = MemWriteM;


endmodule