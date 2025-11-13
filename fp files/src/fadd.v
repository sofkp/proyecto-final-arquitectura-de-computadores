`timescale 1ns / 1ps
module fadd(op_a, op_b, round_mode, mode_fp, result, flags);
  input [31:0] op_a, op_b;
  input round_mode, mode_fp;
  output reg [31:0] result;
  output reg [4:0] flags;
  
  wire [31:0] op_a_conv, op_b_conv;
  wire [31:0] conv_a_out, conv_b_out;

  fp16_32 conv_a(.in16(op_a[15:0]), .out32(conv_a_out));
  fp16_32 conv_b(.in16(op_b[15:0]), .out32(conv_b_out));

  assign op_a_conv = mode_fp ? op_a : conv_a_out;
  assign op_b_conv = mode_fp ? op_b : conv_b_out;

  //unpack los 32 bits
  wire s_a, s_b; 
  wire [22:0] m_a, m_b; 
  wire [7:0] e_a, e_b;
  assign s_a = op_a_conv[31]; assign e_a = op_a_conv[30:23]; assign m_a = op_a_conv[22:0];
  assign s_b = op_b_conv[31]; assign e_b = op_b_conv[30:23]; assign m_b = op_b_conv[22:0];
  
  //flags para identificar casos especiales
  wire a_inf = (e_a == 8'hFF) && (m_a == 0);
  wire b_inf = (e_b == 8'hFF) && (m_b == 0);
  wire a_nan = (e_a == 8'hFF) && (m_a != 0);
  wire b_nan = (e_b == 8'hFF) && (m_b != 0);
  wire a_zero = (e_a == 0) && (m_a == 0);
  wire b_zero = (e_b == 0) && (m_b == 0);
  
  reg [31:0] temp;
  reg f_special; //flag casos especiales
  reg [4:0] e16;
  reg [9:0] m16;
  
  localparam NaN = 32'h7FC00000;
  
  //resultado casos especiales
  always @(*) begin
    f_special = 1;
    if (a_nan || b_nan) temp = NaN;
    else if (a_inf && b_inf) begin 
      if (s_a != s_b) temp = NaN; // inf - inf = NaN
      else temp = s_a ? 32'hFF800000 : 32'h7F800000; //inf + inf = inf 
    end
    else if (a_inf) temp = s_a ? 32'hFF800000 : 32'h7F800000;
    else if (b_inf) temp = s_b ? 32'hFF800000 : 32'h7F800000;
    else if (a_zero && b_zero) temp = 0;
    else if (a_zero) temp = op_b_conv;
    else if (b_zero) temp = op_a_conv;
    else begin
      temp = 0;
      f_special = 0;
    end
    if (f_special && mode_fp == 1'b0) begin
      case (temp[30:23])
        8'hFF: begin
          if (temp[22:0] == 0)
            temp = {16'b0, {temp[31], 5'b11111, 10'b0}}; // inf
          else
            temp = {16'b0, {temp[31], 5'b11111, 10'b1000000000}}; // NaN
        end
        8'h00: begin
          temp = {16'b0, {temp[31], 15'b0}}; // 0
        end
        default: begin
          e16 = (temp[30:23] > 8'd112) ? (temp[30:23] - 8'd112) : 5'd0;
          m16 = temp[22:13];
          temp = {16'b0, {temp[31], e16, m16}};
        end
      endcase
      end
  end
  
  
  
  
  // bit implicito de la mantisa
  //si e != 0, el bit implícito es 1; si e == 0, es 0.
  // se le agrega 3 bits de guarda G, R, S
  reg [26:0] f_a, f_b; 
  always @(*) begin
    f_a = (e_a == 0) ? {1'b0, m_a, 3'b000} : {1'b1, m_a, 3'b000};
    f_b = (e_b == 0) ? {1'b0, m_b, 3'b000} : {1'b1, m_b, 3'b000};
  end
  
  
  //alinear exponente y mantisas
  reg [26:0] sh_a, sh_b; //mantisas shifteadas
  reg [7:0] exp; //exponente alineado
  reg [5:0] shift; // hasta 27
  reg [26:0] tmp_shifted;
  reg [26:0] tmp_src;
  reg [26:0] mask; // helper
  reg sticky_b, sticky_a;
  always @(*) begin
    sticky_a = 1'b0; sticky_b = 1'b0;
    if (e_a >= e_b) begin
      exp = e_a;
      shift = e_a - e_b;
      tmp_src = f_b;
      if (shift >= 27) begin // todos los bits de b se perdieron
        sh_a = f_a;
        sh_b = 27'b0;
        sticky_b = |f_b;
      end else begin
        tmp_shifted = f_b >> shift;
        mask = (27'b1 << shift) - 27'b1; //crea una mascara para obtener los bits que se descartarian al shiftear
        sticky_b = |(f_b & mask); // OR sticky into lsb of shifted to preserve
        sh_a = f_a;
        sh_b = tmp_shifted | {26'b0, sticky_b};
      end
    end else begin
      exp = e_b;
      shift = e_b - e_a;
      tmp_src = f_a;
      if (shift >= 27) begin
        sh_b = f_b;
        sh_a = 27'b0;
        sticky_a = |f_a;
      end else begin
        tmp_shifted = f_a >> shift;
        mask = (27'b1 << shift) - 27'b1;
        sticky_a = |(f_a & mask);
        sh_b = f_b;
        sh_a = tmp_shifted | {26'b0, sticky_a};
      end
    end
  end

  
  
  
  reg s_f; //signo final
  reg [27:0] man; //mantiza
  
  always @ (*) begin
    if (s_a == s_b) begin
      man = {1'b0, sh_a} + {1'b0, sh_b};
      s_f = s_a;
    end else begin
      if (sh_a >= sh_b) begin
        man = {1'b0, sh_a} - {1'b0, sh_b};
        s_f = s_a;
      end else begin
        man = {1'b0, sh_b} - {1'b0, sh_a};
        s_f = s_b;
      end
    end
  end


    /*
    if (sh_a == sh_b) begin //a + b
      man = {1'b0, sh_a} + {1'b0, sh_b};
      s_f = s_a;
    end else begin //a + (-b)
      if(sh_a >= sh_b) begin  // si |a| > = |b| se queda con el signo de a
        man = {1'b0, sh_a} - {1'b0, sh_b};
        s_f = s_a;
      end else begin // si |b| > = |a|
        man = {1'b0, sh_b} - {1'b0, sh_a};
        s_f = s_b;
      end
    end
  end
  */
  
  
 
  reg [26:0] n_m; //mantiza normalizada
  reg [7:0] n_e; // exponente normalizado
  integer i; //iterador
  reg found; //flag
  reg [4:0] lz; //left zeros a shiftear
 
  // normalización 1
  always @(*) begin
    n_m = man[26:0];
    n_e = exp;
    if (man[27]) begin // overflow
      n_m = man[27:1];
      n_e = exp + 1;
    end else begin
      // si n_m es cero, dejar como cero
      if (n_m == 27'b0) begin
        n_m = 27'b0;
        n_e = 8'd0;
      end else begin
        // Leading Zero Detect (LZD) basicamente ver si n_m[26] es 1, sino se shiftea hasta encontrarlo
        found = 1'b0;
        lz = 5'd0;
        for (i = 0; i < 27; i = i + 1) begin
          if (!found && n_m[26 - i]) begin
            found = 1'b1;
            lz = i[4:0];
          end
        end
        if (found) begin
          if (n_e > lz) begin
            n_m = n_m << lz;
            n_e = n_e - lz;
          end else begin // en caso no encontrar 1 se vuelve denormal (exponente llega a 0)
            n_m = n_m << n_e;
            n_e = 8'd0;
          end
        end
      end
    end
  end



 
  //redondeo
  reg [24:0] r_m; //mantisa redondeada
  reg [7:0] f_e; //exponente final
  reg g, r, s;
  
  always @(*) begin
    g = n_m[2];
    r = n_m[1];
    s = n_m[0];
   
    r_m = {1'b0,n_m[26:3]}; //mantiza sin grs
    f_e = n_e;
    
    
    if(round_mode) begin
      // g = 1 y r o s = 1 -> redondeo hacia arriba
      // 2. g = 1 y r=s=0 y  r_m[0]= 1 -> redondeo hacia arriba (numero par)
      if((g && (r || s)) || (g && !r && !s && r_m[0])) begin
        r_m = r_m + 1;
        if (r_m[24]) begin
          r_m = r_m >> 1;
          f_e = f_e + 1;
        end
      end
    end
  end
  
  wire [15:0] result16;
  fp32_16 conv_res(.in32({s_f, f_e, r_m[22:0]}), .out16(result16));
  
  always @(*) begin
    flags = 5'b0;
    result = 32'b0;
    if (f_special) begin
      result = temp;
      if (temp == NaN) flags[4] = 1'b1; // invalid
      else if (temp[30:23] == 8'hFF && temp[22:0] == 0) flags[3] = 1'b1; // overflow (inf)
    end else begin
      result = mode_fp ? {s_f, f_e, r_m[22:0]} : {16'b0, result16};
      if (f_e == 8'hFF && r_m[22:0] == 0) flags[3] = 1'b1; // overflow
      if (f_e == 8'h00 && r_m[22:0] != 0) flags[2] = 1'b1; // underflow
      if (g || r || s) flags[0] = 1'b1; 
    end
  end
  
  
  
endmodule


/*
IEEE punto flotante
	[31][30:23][22:0] -> signo (s) - exponente (e) - mantisa (m)
    - 32 bits bias: 127
    - 16 bits bias: 15
    casos:
    	1. 0<e<255 : result = (−1)^S × 1.F × 2^(E − bias) [normal]
        2. e = 0 y m !=0 : result = (−1)^S × 0.F × 2^(1 − bias) [denormal]
        3. e = 0 y m =0 : result = 0
        4. e = 255 y m=0 : result = inf
        5. e = 255 y m!=0 : NaN
        
     input [31:0] op_a, op_b;
  input [3:0] op_code; //ADD 00, SUB 01, MUL 10, DIV 10
  input mode_fp; // = half (16 bits), 1 = single (32 bits)
  input clk, rst, round_mode, start;
  output reg [31:0] result;
  output reg valid_out;
  output wire [3:0] ALUFlags
  
  wire neg, zero, carry, overflow;
  
  assign neg = result[31]; //resultado negativo o no
  assign zero = (result == 32'b0); //si resultado es 0
*/ 

