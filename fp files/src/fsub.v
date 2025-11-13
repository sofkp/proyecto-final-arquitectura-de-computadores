`timescale 1ns/1ps
module fsub(op_a, op_b, round_mode, mode_fp, result, flags);
  input [31:0] op_a, op_b;
  input round_mode, mode_fp;
  output [31:0] result;
  output [4:0] flags;

  wire [31:0] b_neg;
  assign b_neg = mode_fp ? {~op_b[31], op_b[30:0]}:  {op_b[31:16], ~op_b[15], op_b[14:0]};

  fadd negg(.op_a(op_a), .op_b(b_neg), .round_mode(round_mode),.mode_fp(mode_fp), .result(result), .flags(flags));

endmodule
