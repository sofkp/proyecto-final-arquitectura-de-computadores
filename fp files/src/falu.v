`timescale 1ns / 1ps
module falu(
    input clk,
    input rst,
    input start,
    input [31:0] op_a,
    input [31:0] op_b,
    input [1:0] op_code, // 00=add, 01=sub, 10=mul, 11=div
    input mode_fp, // 0=half, 1=single
    input round_mode,
    output [31:0] result,
    output valid_out,
    output [4:0] flags // {invalid, overflow, underflow, div_zero, inexact}
);

    wire [31:0] add_res, sub_res, mul_res, div_res;
    wire [4:0] add_flags, sub_flags, mul_flags, div_flags;

    // calculos
    fadd m_add(.op_a(op_a),.op_b(op_b),.mode_fp(mode_fp),.round_mode(round_mode),.result(add_res),.flags(add_flags));
    fsub m_sub(.op_a(op_a),.op_b(op_b),.mode_fp(mode_fp),.round_mode(round_mode),.result(sub_res),.flags(sub_flags));
    fmul m_mul(.op_a(op_a),.op_b(op_b),.mode_fp(mode_fp),.round_mode(round_mode),.result(mul_res),.flags(mul_flags));
    fdiv m_div(.op_a(op_a),.op_b(op_b),.mode_fp(mode_fp),.round_mode(round_mode),.result(div_res),.flags(div_flags));

    reg [31:0] ress;
    reg [4:0] flagss;

    always @(*) begin
        case (op_code)
            2'b00: begin ress = add_res; flagss = add_flags; end // add
            2'b01: begin ress = sub_res; flagss = sub_flags; end // sub
            2'b10: begin ress = mul_res; flagss = mul_flags; end // mul
            2'b11: begin ress = div_res; flagss = div_flags; end // div
            default: begin ress   = 32'b0; flagss = 5'b0; end
        endcase
    end

    assign result = ress;
    assign flags = flagss;
    assign valid_out = start;


endmodule
