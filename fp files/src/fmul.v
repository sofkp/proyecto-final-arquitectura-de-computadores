`timescale 1ns / 1ps
module fmul(op_a, op_b, round_mode, mode_fp, result, flags);
  input [31:0] op_a, op_b;
  input round_mode, mode_fp;
  output reg [31:0] result;
  output reg [4:0] flags;

  // conv FP16 <-> FP32 si mode_fp==0
  wire [31:0] op_a_conv, op_b_conv;
  wire [31:0] conv_a_out, conv_b_out;
  fp16_32 conv_a(.in16(op_a[15:0]), .out32(conv_a_out));
  fp16_32 conv_b(.in16(op_b[15:0]), .out32(conv_b_out));
  assign op_a_conv = mode_fp ? op_a : conv_a_out;
  assign op_b_conv = mode_fp ? op_b : conv_b_out;

  // unpack
  wire s_a = op_a_conv[31], s_b = op_b_conv[31];
  wire [7:0] e_a = op_a_conv[30:23], e_b = op_b_conv[30:23];
  wire [22:0] m_a = op_a_conv[22:0], m_b = op_b_conv[22:0];

  // casos especiales
  wire a_inf  = (e_a == 8'hFF) && (m_a == 0);
  wire b_inf  = (e_b == 8'hFF) && (m_b == 0);
  wire a_nan  = (e_a == 8'hFF) && (m_a != 0);
  wire b_nan  = (e_b == 8'hFF) && (m_b != 0);
  wire a_zero = (e_a == 0) && (m_a == 0);
  wire b_zero = (e_b == 0) && (m_b == 0);

  reg [31:0] temp;
  reg f_special, s_f;
  localparam NaN = 32'h7FC00000;
  reg [4:0] e16; reg [9:0] m16;
  reg [26:0] mask;

  // Manejo casos especiales (Inf*0 = NaN invalid; Inf*Inf = Inf (overflow), NaN propagate)
  always @(*) begin
    f_special = 1; // umir caso especial
    s_f = s_a ^ s_b; // signo de multiplicación
    if (a_nan || b_nan) temp = NaN;
    // Inf * 0 = NaN
    else if ((a_inf && b_zero) || (a_zero && b_inf)) temp = NaN; // invalid
    // Inf * X = Inf o Inf * Inf = Inf
    else if (a_inf || b_inf) temp = {s_f, 8'hFF, 23'b0}; // ±Inf
    // 0 * x = 0 o 0 * 0 = 0
    else if (a_zero || b_zero) temp = {s_f, 31'b0}; // ±0
    else begin
      f_special = 0; // No es caso especial
      temp = 0;
    end

    // convertir a FP16 si mode_fp == 0
    if (f_special && mode_fp == 1'b0) begin
      case (temp[30:23])
        8'hFF: begin
          if (temp[22:0] == 0)
            temp = {16'b0, {temp[31], 5'b11111, 10'b0}}; // inf
          else
            temp = {16'b0, {temp[31], 5'b11111, 10'b1000000000}}; // NaN
        end
        8'h00: temp = {16'b0, {temp[31], 15'b0}};
        default: begin
          e16 = (temp[30:23] > 8'd112) ? (temp[30:23] - 8'd112) : 5'd0;
          m16 = temp[22:13];
          temp = {16'b0, {temp[31], e16, m16}};
        end
      endcase
    end
  end

  // bit implicito
  reg [23:0] f_a, f_b;
  always @(*) begin
    f_a = (e_a == 0) ? {1'b0, m_a} : {1'b1, m_a};
    f_b = (e_b == 0) ? {1'b0, m_b} : {1'b1, m_b};
  end

  // multiplicacion mantisas y proceso de exponente
  reg [47:0] prod, m_to_norm;
  integer exp_unb_a, exp_unb_b, exp_unb_sum; // unbiased exponents (signed)
  reg signed [10:0] exp_after; // signed temp
  reg [26:0] n_m; // 27 bits (24 mantissa + GRS)
  reg [7:0] n_e;
  reg sticky, acum_sticky;
  integer shift_amt, shift_left, i, j;

  always @(*) begin
    prod = f_a * f_b; // 24x24 -> 48
    // unbiased exponents: normal: e-127, subnormal: -126
    exp_unb_a = (e_a == 8'd0) ? -126 : (e_a - 127);
    exp_unb_b = (e_b == 8'd0) ? -126 : (e_b - 127);
    exp_unb_sum = exp_unb_a + exp_unb_b;
    // default
    n_m = 27'b0;
    n_e = 8'd0;
    sticky = 1'b0;
    exp_after = 0;
    shift_left = 0;
    m_to_norm = prod;

    if (prod == 48'b0) begin
      // resultado exactamente 0
      n_m = 27'b0;
      n_e = 8'd0;
      sticky = 1'b0;
    end else begin
      // escoger ventana de 27 bits (incluyendo GRS) según prod[47]
      // punto decimal entre prod[46] y prod[45]
      if (prod[47] == 1'b0 && prod[46] == 1'b0) begin
        // CASO 1:
        // producto en <1.0. buscar 1 msb desde bit 45
        for (i = 0; i <= 46; i = i + 1) begin
          if(!shift_left && m_to_norm[45 - i]) begin
            shift_left = i + 1;
          end
        end
        if (shift_left>0) begin
          if(shift_left>46) shift_left = 46;
          m_to_norm = prod << shift_left;
          exp_after = exp_unb_sum - shift_left; // reducir exponente
        end else begin
          m_to_norm = prod; // 0
          exp_after = exp_unb_sum;
        end
      end else begin
        // CASO 2:
        // producto >= 1
        m_to_norm = prod;
        exp_after = exp_unb_sum;
      end

      //extraer grs y normalizar por derecha
      if(m_to_norm[47]) begin
        // caso 1: prod en [2,4) -> 1x.frac
        n_m = m_to_norm[47:21]; // 27b
        sticky = |m_to_norm[20:0];
        exp_after = exp_after + 1; // +1 por shift a la derecha
      end else begin
        // caso 2: producto en [1,2) -> 01.frac
        n_m = m_to_norm[46:20];
        sticky = |m_to_norm[19:0];
      end

      // manjo overflow o underflow, denormalizacion
      if (exp_after + 127 >= 255) begin
        // overflow a +Inf
        n_e = 8'hFF;
        n_m = 27'b0; // resultado es inf, mantisa 0
        sticky = 1'b0; 
      end else if (exp_after + 127 <= 0) begin
        // resultado subnormal o 0 : desplazar mantisa a la derecha
        shift_amt = 1 - (exp_after + 127);
        if (shift_amt >= 27) begin
          // demasiado pequeño : 0
          // inexacto si n_m o sticky tenian bits
          sticky = |n_m | sticky; 
          n_m = 27'b0;
          n_e = 8'h00;
        end else begin
          // denormalizar
          // calcular sticky de todos los bits que se perderán
          mask = (27'h1 << shift_amt) -1;
          acum_sticky = |(n_m & mask);
          // Or con el stikcy original
          // shift right
          n_m = n_m >> shift_amt;
          sticky = acum_sticky; // nuevo sticky para el redondeo
          n_e = 8'h00; // exp de subnormal
        end
      end else begin
        // normal representable
        n_e = exp_after + 127;
      end
    end
  end

  // redondeo round-to-nearest-even (usar G,R,S)
  reg g, rbit, sbit;
  reg [24:0] r_m; // 25 bits for rounding carry
  reg [7:0] f_e;
  always @(*) begin
    g = n_m[2];
    rbit = n_m[1];
    sbit = n_m[0] | sticky;
    r_m = {1'b0, n_m[26:3]}; // 24 bits mantissa (with leading 0 to detect carry)
    f_e = n_e;

    if (round_mode) begin
      if ((g && (rbit || sbit)) || (g && !rbit && !sbit && r_m[0])) begin
        r_m = r_m + 1;
        // carry out from rounding
        if (r_m[24]) begin
          // mantissa overflowed -> shift right one and increment exponent
          r_m = r_m >> 1;
          if (f_e != 8'hFF) f_e = f_e + 1;
          else begin
            // if f_e was FF, result becomes Inf (leave mantissa 0)
            r_m = 25'b0;
          end
        end
      end
    end
  end

  // ensamblado final y flags
  
  wire [15:0] result16;
  fp32_16 conv_res(.in32({s_f, f_e, r_m[22:0]}), .out16(result16));

  always @(*) begin
    flags = 5'b0; // {invalid, overflow, underflow, div_zero(not used), inexact}
    result = 32'b0;

    if (f_special) begin
      result = temp;
      // invalid: NaN produced by Inf*0 or NaN input
      if ((a_nan || b_nan) || ((a_inf && b_zero) || (b_inf && a_zero))) flags[4] = 1'b1;
      // overflow: if special result is Inf (from a_inf||b_inf and not invalid)
      if ((temp[30:23] == 8'hFF) && (temp[22:0] == 0) && !( (a_inf && b_zero)||(b_inf && a_zero) )) flags[3] = 1'b1;
    end else begin
      // normal assembly
      result = mode_fp ? {s_f, f_e, r_m[22:0]} : {16'b0, result16};

      // overflow: exponent reached max
      if (f_e == 8'hFF && r_m[22:0] == 0) flags[3] = 1'b1;

      // inexact: any rounding/truncation
      if (g || rbit || sbit) flags[0] = 1'b1;

      // underflow: result is subnormal (exponent 0 and mantissa non-zero)
      if (f_e == 8'h00 && (g || rbit || sbit)) begin
        // IEEE: underflow flag set when result is tiny *and* inexact
        // here we set underflow if subnormal produced; inexact is flagged separately
        flags[2] = 1'b1;
      end

    end
  end

endmodule
