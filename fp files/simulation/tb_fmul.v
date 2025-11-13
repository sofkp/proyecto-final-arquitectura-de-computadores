`timescale 1ns/1ps

module fp32_16(input [31:0] in32, output reg [15:0] out16);
    wire sign;
    wire [7:0] exp32;
    wire [22:0] frac32;

    assign sign  = in32[31];
    assign exp32 = in32[30:23];
    assign frac32 = in32[22:0];

    reg [4:0] exp16;
    reg [9:0] frac16;
    integer exp_unbias;

    always @(*) begin
        if (exp32 == 8'b0 && frac32 == 0)
            out16 = {sign, 15'b0}; // ±0
        else if (exp32 == 8'hFF) begin
            // Inf o NaN
            if (frac32 == 0)
                out16 = {sign, 5'b11111, 10'b0}; // Inf
            else
                out16 = {sign, 5'b11111, 10'b1}; // NaN
        end else begin
            exp_unbias = exp32 - 127 + 15;

            if (exp_unbias >= 31)
                out16 = {sign, 5'b11111, 10'b0}; // Overflow → Inf
            else if (exp_unbias <= 0)
                out16 = {sign, 15'b0}; // Underflow → 0
            else begin
                exp16 = exp_unbias[4:0];
                frac16 = frac32[22:13]; // truncar mantisa (23→10)
                out16 = {sign, exp16, frac16};
            end
        end
    end
endmodule
module fp16_32(input [15:0] in16, output reg [31:0] out32);
    wire sign;
    wire [4:0] exp16;
    wire [9:0] frac16;
    reg [7:0] exp32;
    reg [22:0] frac32;
    integer shift;
    reg [9:0] frac_shifted;

    assign sign = in16[15];
    assign exp16 = in16[14:10];
    assign frac16 = in16[9:0];

    always @(*) begin
        if (exp16 == 5'b00000) begin
            if (frac16 == 0)
                out32 = {sign, 31'b0}; // ±0
            else begin
                // denormal -> normalizado
                
                shift = 0;
                frac_shifted = frac16;
                while (frac_shifted[9] == 0 && shift < 10) begin
                    frac_shifted = frac_shifted << 1;
                    shift = shift + 1;
                end
                exp32 = 8'd127 - 15 - shift + 1;
                frac32 = {frac_shifted[8:0], 14'b0};
                out32 = {sign, exp32, frac32};
            end
        end else if (exp16 == 5'b11111) begin
            // Inf o NaN
            exp32 = 8'hFF;
            frac32 = {frac16, 13'b0};
            out32 = {sign, exp32, frac32};
        end else begin
            // Normal
            exp32 = exp16 - 5'd15 + 8'd127;
            frac32 = {frac16, 13'b0};
            out32 = {sign, exp32, frac32};
        end
    end
endmodule

module tb_fmul;

  reg [31:0] op_a, op_b;
  reg round_mode, mode_fp;
  wire [31:0] result;
  wire [4:0] flags;

  fmul uut (
    .op_a(op_a),
    .op_b(op_b),
    .round_mode(round_mode),
    .mode_fp(mode_fp),
    .result(result),
    .flags(flags)
  );

  initial begin
    $display("===== TEST FMUL: DENORMAL HANDLING =====");
    round_mode = 1; // round to nearest
    mode_fp = 1;    // single precision (float32)

    // 1. Números normales pequeños -> producto denormal
    op_a = 32'h00800000; // 1.175494e-38 (float32 más pequeño normal)
    op_b = 32'h00800000; 
    #10;
    $display("Case1: small*small = %h (flags=%b)", result, flags);

    // 2. Subnormal explícito multiplicado por 2.0
    op_a = 32'h00000010; // denormal tiny number
    op_b = 32'h40000000; // 2.0
    #10;
    $display("Case2: denormal*2.0 = %h (flags=%b)", result, flags);

    // 3. Denormal * denormal
    op_a = 32'h00000020;
    op_b = 32'h00000020;
    #10;
    $display("Case3: denormal*denormal = %h (flags=%b)", result, flags);

    // 4. normal * denormal (otro signo)
    op_a = 32'h80000010; // denormal negativo
    op_b = 32'h3F800000; // 1.0
    #10;
    $display("Case4: -denormal*1.0 = %h (flags=%b)", result, flags);

    $finish;
  end

endmodule
