`timescale 1ns / 1ps
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
                exp32 = 8'd127 - 15 - shift;
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