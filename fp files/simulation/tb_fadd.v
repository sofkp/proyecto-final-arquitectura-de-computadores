`timescale 1ns/1ps
module tb_fadd();

  reg [31:0] a, b;
  reg round_mode, mode_fp;
  wire [31:0] result;

  fadd m1(.op_a(a),.op_b(b),.round_mode(round_mode),.mode_fp(mode_fp),.result(result));

  initial begin
    mode_fp = 1;
    // 0 + 0 = 0
    a = 32'h00000000; b = 32'h00000000; round_mode = 0; #10

    // 0.5 (0x3f000000) + 2.25 (0x40100000) = 2.75 (0x40300000)
    a = 32'h3f000000; b = 32'h40100000; round_mode = 0; #10

    // 1.5 + (-1.5) = 0
    a = 32'h3FC00000; b = 32'hBFC00000; round_mode = 1; #10

    // +inf + +inf = +inf
    a = 32'h7F800000; b = 32'h7F800000; round_mode = 1; #10

    // +inf + -inf = NaN
    a = 32'h7F800000; b = 32'hFF800000; round_mode = 1; #10
    
     //2.25 (0x40100000) + 2.25 (0x40100000) = 4.5 (0x40900000)
    a = 32'h40100000; b = 32'h40100000; round_mode = 1; #10
    
    //4.5 (0x40900000) + 0.249999 (0xh3E7FFFFF) 
    a = 32'h40900000; b = 32'h3E7FFFFF;
     round_mode = 1; #10 //4.75 (0x40980000)
     round_mode = 0; #10 //4.7499995 (0x4097ffff)
    
    // 114687.99 (0x47dfffff)+ 1.1754944e-38 (0x00800000 denormal)=
    a = 32'h47dfffff; 
    b = 32'h00800000;

    //16 bits
    mode_fp = 0; round_mode = 0;

    // 0.5 (0x3800) + 2.25 (0x4100) ≈ 2.75 (0x40300000)
    a = 32'h00003800; b = 32'h00004100; #10

    // 1.5 (0x3E00) + (-1.5) (0xBE00) = 0
    a = 32'h00003E00; b = 32'h0000BE00; #10

    // 2.25 (0x4100) + 2.25 (0x4100) ≈ 4.5 (0x40900000)
    a = 32'h00004100; b = 32'h00004100; #10


    $finish;
  end
endmodule