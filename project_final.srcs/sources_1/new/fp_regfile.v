`timescale 1ns / 1ps

module fp_regfile(input  clk, 
               input  we3,
               input  [ 4:0] a1, a2, a3, 
               input  [31:0] wd3, 
               output [31:0] rd1, rd2); 

  reg [31:0] rf[31:0]; 

  // write third port on rising edge of clock (A3/WD3/WE3)
  always @(negedge clk) begin 
    if (we3) begin
        rf[a3] <= wd3; 
        end
  end
  
  // read two ports combinationally (A1/RD1, A2/RD2)
  // register 0 hardwired to 0
  assign rd1 = (a1 != 0) ?  rf[a1] : 0; 
  assign rd2 = (a2 != 0) ?  rf[a2] : 0; 
endmodule