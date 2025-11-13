`timescale 1ns/1ps
module fdiv(op_a, op_b, round_mode, mode_fp, result, flags);
  input round_mode, mode_fp;
  input [31:0] op_a, op_b;
  output reg [31:0] result;
  output reg [4:0] flags;

  // Conversores FP16 a FP32
  wire [31:0] conv_a_out, conv_b_out;
  fp16_32 conv_a(.in16(op_a[15:0]), .out32(conv_a_out));
  fp16_32 conv_b(.in16(op_b[15:0]), .out32(conv_b_out));

  // Si mode_fp = 1 usar FP32 directamente, si no: convertir desde FP16
  wire [31:0] op_a_conv = mode_fp ? op_a : conv_a_out;
  wire [31:0] op_b_conv = mode_fp ? op_b : conv_b_out;

  // Unpack 32b
  wire s_a = op_a_conv[31];
  wire [7:0] e_a = op_a_conv[30:23];
  wire [22:0] m_a = op_a_conv[22:0];
  wire s_b = op_b_conv[31];
  wire [7:0] e_b = op_b_conv[30:23];
  wire [22:0] m_b = op_b_conv[22:0];

  // Casos especiales
  wire a_inf  = (e_a == 8'hFF) && (m_a == 0);
  wire b_inf  = (e_b == 8'hFF) && (m_b == 0);
  wire a_nan  = (e_a == 8'hFF) && (m_a != 0);
  wire b_nan  = (e_b == 8'hFF) && (m_b != 0);
  wire a_zero = (e_a == 8'h00) && (m_a == 0);
  wire b_zero = (e_b == 8'h00) && (m_b == 0);

  // constantes
  localparam NaN32 = 32'h7FC00000;
  localparam POS_INF = 32'h7F800000;
  localparam NEG_INF = 32'hFF800000;

  reg f_special; // resultado viene de especial case
  reg [31:0] temp; // resultado para casos especiales
  reg [7:0] f_e; // exponente final
  reg [24:0] r_m; // 25-bit mantisa o 24+1 para detectar carry en redondeo
  reg g, rr, ss; // guard, round, sticky
  reg inv, ovf, und, dz, inx;

  // Resto
  reg rem_nz;

  integer shift_count;
  reg[26:0] q_norm;

  reg [23:0] M_a, M_b; // 24-bit mantissas
  reg signed [16:0] exp_a_unb, exp_b_unb; // exponent unbiased
  reg signed [17:0] exp_diff;
  reg signed [17:0] exp_res_unb; // unbiased
  reg [50:0] numer; // numerator amplio para obtener GRS
  reg [26:0] q_extended; // 24 bits significand + 3 GRS = 27 bits
  reg [23:0] sig24; // 24-bit significand candidate
  reg [2:0] grs_bits; // guard, round, sticky
  reg normalized_msb; // si msb está en posición esperada (1.x)

  wire [15:0] res16;
  wire [31:0] back32;
  reg [31:0] float32_res;

  fp32_16 conv_res(.in32(float32_res), .out16(res16));
  fp16_32 conv_back(.in16(res16), .out32(back32));

  // casos especiales:
  always @(*) begin
    // resultado es un caso especial hasta demostrar lo contrario
    f_special = 1'b1;
    temp = 32'b0;

    // si alguno de los operandos es NAN, resultado es NAN
    if (a_nan || b_nan) temp = NaN32;
    // inf / inf = NAN
    else if (a_inf && b_inf) temp = NaN32;
    // inf / finito = +- inf. El signo depende de un xor de los signos
    else if (a_inf) temp = (s_a ^ s_b) ? NEG_INF : POS_INF;
    // finito / inf = +-0. signo depende de un xor de los signos
    else if (b_inf) temp = (s_a ^ s_b) ? 32'h80000000 : 32'h00000000;
    // 0 / 0 = nan
    else if (a_zero && b_zero) temp = NaN32;
    // 0 / finito = +- 0. signo depende del xor de los signos
    else if (a_zero) temp = (s_a ^ s_b) ? 32'h80000000 : 32'h00000000;
    // finito / 0 = +- inf
    else if (b_zero) temp = (s_a ^ s_b) ? NEG_INF : POS_INF;
    // si no cumple ninguno, es división normal
    else f_special = 1'b0;
  end

  // división normal:
  always @(*) begin
    // inicializa banderas y registros internos
    inv = 1'b0; ovf = 1'b0; und = 1'b0; dz = 1'b0; inx = 1'b0;
    f_e = 8'b0; r_m = 25'b0; g = 1'b0; rr = 1'b0; ss = 1'b0;
    rem_nz = 1'b0;
    // Si es caso especial:
    if (f_special) begin
      // determina que banderas activar segun sea el caso
      // es invalid si la operación no tiene un resultado definido, si hay nan, inf/inf, o 0/0
      inv = (a_nan || b_nan || (a_inf && b_inf) || (a_zero && b_zero)) ? 1'b1 : 1'b0;
      // dividedZero si el divisor es cero y el numerador no lo es
      dz  = (b_zero && !a_zero) ? 1'b1 : 1'b0;
      
      // en estos casos no hay overflow, así que no se activa
      ovf = 1'b0; und = 1'b0; inx = 1'b0;

      // resultado especial determinado antes
      float32_res = temp;
      // si esta en fp16, el resultado se convierte
      if(!mode_fp) result = {16'b0, res16};
      else result = temp;

      flags = {inv, ovf, und, dz, inx};
    end else begin
      // si no es caso especial

      // Construir mantisas con bit implícito
      // en denormales el bit implicito es 0
      M_a = (e_a == 8'h00) ? {1'b0, m_a} : {1'b1, m_a};
      M_b = (e_b == 8'h00) ? {1'b0, m_b} : {1'b1, m_b};

      // quita bias de exponentes
      exp_a_unb = (e_a == 8'h00) ? (1 - 127) : (e_a - 127);
      exp_b_unb = (e_b == 8'h00) ? (1 - 127) : (e_b - 127);

      // diferencia de expoentnes
      exp_diff = exp_a_unb - exp_b_unb;
      
      // construir numerador extendido para mantener la precision grs
      numer = {M_a, 26'b0};
      
      // divide las mantisas, manteniendo la precision extendida
      if (M_b != 0) q_extended = numer / M_b;
      else q_extended = 27'b0;

      // desplazar a la izq hasta el primer 1 para normalizar
      q_norm = q_extended;
      shift_count = 0;
      while (q_norm[26] == 0 && shift_count < 26)begin
        q_norm = q_norm << 1;
        shift_count = shift_count +1;
      end

      // ajuste de exponente en base a desplazamientos
      exp_res_unb = exp_diff - shift_count;

      // extrae parte significativa y los 3 bits grs
      sig24 = q_norm[26:3];
      grs_bits = q_norm[2:0];
      g  = grs_bits[2];
      rr = grs_bits[1];
      ss = grs_bits[0];

      // provisional mantisa para detectar carry en rounding
      r_m = {1'b0, sig24};

      // redondeo al más cercano
      if ((g && (rr || ss)) || (g && !rr && !ss && r_m[0])) begin
        r_m = r_m + 1'b1;
        // si el redondeo causa overflow de mantisa
        if (r_m[24]) begin
          // renormaliza desplazando y ajusta exponente
          r_m = r_m >> 1;
          exp_res_unb = exp_res_unb + 1;
        end
      end

      // Marca inexactitud si hay residuo distinto de cero
      if (M_b != 0) rem_nz = ((numer % M_b) != 0);
      else rem_nz = 1'b1;

      // overflow y underflow manejo
      if (exp_res_unb > 127) begin
        // overflow resultado +- inf
        ovf = 1'b1;
        // si es overflow, el resultado es inexacto
        inx = 1'b1;
        f_e = 8'hFF;
        r_m = 25'b0;
      end else if (exp_res_unb < -126) begin
        // underflow a subnormal o cero
        und = 1'b1;
        if (rem_nz || g || rr || ss || (r_m!=0)) inx = 1'b1;
        f_e = 8'h00;
        r_m = 25'b0;
      end else begin
        // caso normal se vuelve a aplicar bias
        f_e = exp_res_unb + 127;
        // marca inexacto si hubo redondeo o residuo
        if (g || rr || ss || rem_nz) inx = 1'b1;
      end

      // Resultado FP32
      float32_res={(s_a ^ s_b), f_e, r_m[22:0]};

      // Si modo FP16, convertir a FP16
      if (!mode_fp) begin
        // resultado empaquetado, low 16 b contienen la half
        result = {16'b0, res16};
        // detecta underflow si res16 es +-0 pero float32_res no lo era
        if ((res16 == 16'h0000 || res16 == 16'h8000) && (float32_res[30:0] != 31'b0)) und = 1'b1;
        // detecta oevrflow si el exponente res16 se saturó a todo 1s
        if ((res16 & 16'h7C00) == 16'h7C00) begin
          // si float32_res no era inf/nan, es overflow
          if(!((float32_res[30:23] == 8'hFF) && (float32_res[22:0] != 0))) begin
            ovf = 1'b1;
            inx = 1'b1; // como es overflow, es inexcato
          end
        end
        // si convertir ida y vuelta no coincide con el float32 original es inexacto
        if(back32 != float32_res) inx = 1'b1;
      end else begin
        // modo fp32 devuelve float32_res tal cual estaba
        result = float32_res;
      end
      // banderas finales
      inv = 1'b0;
      dz= 1'b0;
      flags = {inv, ovf, und, dz, inx};
    end
  end

endmodule
