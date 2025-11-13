`timescale 1ns/1ps
module tb_fdiv();
  reg round_mode, mode_fp;
  reg [31:0] a, b;
  wire [31:0] r;

  fdiv m4(.op_a(a),.op_b(b),.round_mode(round_mode),.mode_fp(mode_fp),.result(r));

  initial begin
    round_mode = 0;
    //32 bits
     mode_fp = 1;
    // 5.5 / 2 = 2.75 (0x40300000)
    a = 32'h40B00000; b = 32'h40000000; #10;

    // 2.25 / 5.5 = ~0.4090909 (0x3ed1745d)
    a = 32'h40100000; b = 32'h40B00000; #10;

    // 1.5 / 1.5 = 1 (0x3f800000)
    a = 32'h3FC00000; b = 32'h3FC00000; #10

    // 1 / 0 = nan
    a = 32'h3F800000;b = 32'h00000000;#10
    
    
    //16 bits
    mode_fp = 0;

    // 5.5 / 2 = 2.75 (half: 0x4580 / 0x4000 → 0x4140)
    a = 32'h00004580; b = 32'h00004000; #10;

    // 2.25 / 5.5 ≈ 0.4091 (half: 0x4100 / 0x4580 → 0x36A0)
    a = 32'h00004100; b = 32'h00004580; #10;

    // 1.5 / 1.5 = 1.0 (half: 0x3E00)
    a = 32'h00003E00; b = 32'h00003E00; #10;

    // 1 / 0 = NaN (half: 0x3C00 / 0x0000 → NaN)
    a = 32'h00003C00; b = 32'h00000000; #10;

    // número pequeño / grande (underflow posible)
    a = 32'h00002000; b = 32'h00007C00; #10;


    $finish;
  end
endmodule
