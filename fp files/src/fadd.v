`timescale 1ns / 1ps
module fadd(op_a, op_b, round_mode, mode_fp, result, flags);

  input [31:0] op_a, op_b;
  input round_mode, mode_fp;
  output reg [31:0] result;
  output reg [4:0]  flags;

  wire [31:0] conv_a_out, conv_b_out;
  fp16_32 convA(.in16(op_a[15:0]), .out32(conv_a_out));
  fp16_32 convB(.in16(op_b[15:0]), .out32(conv_b_out));

  wire [31:0] op_a_conv = mode_fp ? op_a : conv_a_out;
  wire [31:0] op_b_conv = mode_fp ? op_b : conv_b_out;

  wire s_a = op_a_conv[31];
  wire s_b = op_b_conv[31];
  wire [7:0] e_a = op_a_conv[30:23];
  wire [7:0] e_b = op_b_conv[30:23];
  wire [22:0] m_a = op_a_conv[22:0];
  wire [22:0] m_b = op_b_conv[22:0];

  wire a_nan  = (e_a==8'hFF && m_a!=0);
  wire b_nan  = (e_b==8'hFF && m_b!=0);
  wire a_inf  = (e_a==8'hFF && m_a==0);
  wire b_inf  = (e_b==8'hFF && m_b==0);
  wire a_zero = (e_a==0    && m_a==0);
  wire b_zero = (e_b==0    && m_b==0);

  reg [31:0] temp;
  reg f_special;

  always @(*) begin
    f_special = 1'b1;
    temp      = 32'b0;

    if (a_nan || b_nan) temp = 32'h7FC00000;
    else if (a_inf && b_inf && (s_a!=s_b)) temp = 32'h7FC00000;
    else if (a_inf) temp = {s_a,8'hFF,23'b0};
    else if (b_inf) temp = {s_b,8'hFF,23'b0};
    else if (a_zero && b_zero) temp = 32'b0;
    else if (a_zero) temp = op_b_conv;
    else if (b_zero) temp = op_a_conv;
    else begin
      f_special = 1'b0;
      temp      = 32'b0;
    end
  end

  wire [23:0] f_a = (e_a==0) ? {1'b0,m_a} : {1'b1,m_a};
  wire [23:0] f_b = (e_b==0) ? {1'b0,m_b} : {1'b1,m_b};

  wire [7:0] exp_big  = (e_a>=e_b)? e_a : e_b;
  wire [7:0] shiftA   = exp_big - e_a;
  wire [7:0] shiftB   = exp_big - e_b;

  wire [26:0] A_pre = (shiftA>=27)? 27'b0 : ({f_a,3'b000} >> shiftA);
  wire [26:0] B_pre = (shiftB>=27)? 27'b0 : ({f_b,3'b000} >> shiftB);

  wire stickyA = (shiftA>=27)? |f_a : |({f_a,3'b000} & ((27'h1<<shiftA)-1));
  wire stickyB = (shiftB>=27)? |f_b : |({f_b,3'b000} & ((27'h1<<shiftB)-1));

  wire [26:0] sh_a = A_pre | {26'b0,stickyA};
  wire [26:0] sh_b = B_pre | {26'b0,stickyB};

  reg [27:0] man;
  reg s_f;

  always @(*) begin
    if (s_a == s_b) begin
      man = {1'b0,sh_a} + {1'b0,sh_b};
      s_f = s_a;
    end else begin
      if (sh_a >= sh_b) begin
        man = {1'b0,sh_a} - {1'b0,sh_b};
        s_f = s_a;
      end else begin
        man = {1'b0,sh_b} - {1'b0,sh_a};
        s_f = s_b;
      end
    end
  end

  reg [26:0] n_m;
  reg [7:0]  n_e;

  integer i;
  reg found;

  always @(*) begin
    if (man[27]) begin
      n_m = man[27:1];
      n_e = exp_big + 1;
    end else begin
      n_m = man[26:0];
      n_e = exp_big;

      if (n_m == 0) begin
        n_e = 0;
      end else begin
        found = 1'b0;
        for (i=0; i<27; i=i+1) begin
          if (!found && n_m[26-i]) begin
            n_m = n_m << i;
            n_e = n_e - i;
            found = 1'b1;
          end
        end
      end
    end
  end

  wire g = n_m[2];
  wire r = n_m[1];
  wire s = n_m[0];

  reg [24:0] r_m;
  reg [7:0]  f_e;

  always @(*) begin
    r_m = {1'b0,n_m[26:3]};
    f_e = n_e;

    if (round_mode) begin
      if ((g&&(r||s)) || (g&&!r&&!s&&r_m[0])) begin
        r_m = r_m + 1'b1;
        if (r_m[24]) begin
          r_m = r_m >> 1;
          f_e = f_e + 1'b1;
        end
      end
    end
  end

  wire [31:0] res32 = {s_f,f_e,r_m[22:0]};

  wire [15:0] result16;
  fp32_16 convR(.in32(res32), .out16(result16));

  always @(*) begin
    if (f_special) begin
      result = mode_fp ? temp : {16'b0,result16};
      flags  = { (temp==32'h7FC00000), 1'b0,1'b0,1'b0,1'b0 };
    end else begin
      result = mode_fp ? res32 : {16'b0,result16};
      flags  = { 1'b0,(f_e==8'hFF), (f_e==8'h00 && r_m[22:0]!=0), 1'b0, (g||r||s) };
    end
  end

endmodule
