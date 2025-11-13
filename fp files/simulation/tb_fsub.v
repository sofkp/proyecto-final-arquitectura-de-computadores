`timescale 1ns/1ps
module tb_fsub();
  reg [31:0] a, b;
  reg round_mode,mode_fp;
  wire [31:0] result;

  fsub m2 (.op_a(a),.op_b(b),.round_mode(round_mode),.mode_fp(mode_fp),.result(result));

  initial begin
    round_mode = 0;
    // 32 bits
    mode_fp = 1;
    //  16384(0x46800000) - 512 (0x44000000) = 15,872 (0x46780000)
    a = 32'h46800000; b = 32'h44000000; #10

    // -0.000118255615 (0xb8f80000) - 1 (0x3f800000) = -1.0001183 (0xbf8003e0)
    a = 32'hb8f80000; b = 32'h3f800000; #10
    
    // 2.75 (0x40300000) - -1.5 (0xbfc00000) = -1.25 (0x40880000)
    a = 32'h40300000; b = 32'hbfc00000;#10

    // (-3.75) (0xC0700000) - (-2.5) (0xC0200000) = (-1.25) (0xBFA00000)
    a = 32'hC0700000; b = 32'hC0200000; #10
    
    //16 bits
    mode_fp = 0;
    // 16.0 - 2.0 = 14.0 (half: 0x4800 - 0x4000 = 0x4700)
    a = 32'h00004800; b = 32'h00004000; #10;

    // -0.5 - 1.0 = -1.5 (half: 0xBC00 - 0x3C00 = 0xBE00)
    a = 32'h0000BC00; b = 32'h00003C00; #10;

    // 2.75 - (-1.5) = 4.25 (half: 0x4140 - 0xBE00 = 0x4210)
    a = 32'h00004140; b = 32'h0000BE00; #10;

    // (-3.75) - (-2.5) = (-1.25) (half: 0xC070 - 0xC020 = 0xBFA0 aprox)
    a = 32'h0000C070; b = 32'h0000C020; #10;

    // 0.0 - 1.0 = -1.0 (half: 0x0000 - 0x3C00 = 0xBC00)
    a = 32'h00000000; b = 32'h00003C00; #10;

    $finish;
  end
endmodule
