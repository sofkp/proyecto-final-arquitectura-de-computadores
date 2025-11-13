`timescale 1ns / 1ps
module fp32_16(input [31:0] in32, output reg [15:0] out16);
    wire sign;
    wire [7:0] exp32;
    wire [22:0] frac32;

    assign sign  = in32[31];
    assign exp32 = in32[30:23];
    assign frac32 = in32[22:0];

    reg [4:0] exp16;
    reg [9:0] frac16_unr;
    reg [10:0] frac16_r;
    integer exp_unbias;

    // registros para denormalizacion
    integer shift;
    reg [23:0] m32_f, m_shift;
    reg g, r, s;

    always @(*) begin
        // casos especiales
        if (exp32 == 8'b0 && frac32 == 0)
            out16 = {sign, 15'b0}; // +-0
        else if (exp32 == 8'hFF) begin
            // Inf o NaN
            if (frac32 == 0)
                out16 = {sign, 5'b11111, 10'b0}; // Inf
            else
                out16 = {sign, 5'b11111, {frac32[22], 9'b1}}; // NaN
        end // caso normales / subnormales
        else begin
            // exponente sin sesgo
            exp_unbias = exp32 - 127 + 15;
            g =0; r=0; s=0;

            // overflow
            if (exp_unbias >= 31)
                out16 = {sign, 5'b11111, 10'b0}; // Overflow → Inf
            // normal
            else if (exp_unbias >= 1) begin
                exp16 = exp_unbias[4:0];
                frac16_unr = frac32[22:13]; //10b

                // obt bits g r s para redondear
                g = frac32[12];
                r = frac32[11];
                s = |frac32[10:0];

                // redondeo
                if((g && (r ||s)) || (g && !r && !s && frac16_unr[0])) begin
                    frac16_r = {1'b0, frac16_unr} +1;
                    // comprobar si redondeo causo overflow
                    if(frac16_r[10]) begin
                        exp16 = exp16 +1;
                        // redondeo hasata infinito?
                        if(exp16 == 5'b11111) out16 = {sign, 5'b11111, 10'b0}; // inf
                        else out16 = {sign, exp16, 10'b0}; //mantisa 0
                    end else out16 = {sign, exp16, frac16_r[9:0]}; // redondeo normal
                end else out16 = {sign, exp16, frac16_unr}; // sin redondeo
            end
            // subnormal (denormal)
            else begin
                exp16 = 5'b0; // exp de subnormal es 0
                shift = 1-exp_unbias; // cant de bits a desplazar a la derecha
                m32_f = {1'b1, frac32};

                //desplazar para denormalizar
                if(shift > 24) begin
                    m_shift = 24'b0;
                    s = |m32_f; // Si hay algo, se vuelve sticky
                    g = 0;
                    r = 0;
                end else begin
                    m_shift = m32_f >> shift;
                    s= |(m32_f & ((24'b1 << shift) - 1)); // Bits perdidos por el shift
                end

                frac16_unr = m_shift[22:13];
                g = m_shift[12];
                r = m_shift[11];
                s = s | |m_shift[10:0];

                // redondeo to nearest even
                if((g && (r||s)) || (g && !r && !s && frac16_unr[0])) begin
                    frac16_r = {1'b0, frac16_unr} +1;
                    // comprobar si redondeo causo overflow al normal mas peq
                    if(frac16_r[10]) out16 = {sign, 5'b00001, 10'b0}; // Redondeado a 1.0
                    else out16 = {sign, 5'b0, frac16_r[9:0]}; // denormal redondeado
                end else out16 = {sign, 5'b0, frac16_unr}; // sin redondeo
            end
        end
    end
endmodule