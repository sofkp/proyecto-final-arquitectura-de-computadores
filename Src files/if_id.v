`timescale 1ns / 1ps

module if_id(input clk, input reset, 
             input [31:0] InstrF, input [31:0] PCF, input PCPlus4F,
             output reg [31:0]  InstrD, PCD, PCPlus4D);

    always @(posedge clk) begin
        if (reset) begin
          InstrD   <= 32'b0;
          PCD      <= 32'b0;
          PCPlus4D <= 32'b0;
        end else begin
          InstrD   <= InstrF;
          PCD      <= PCF;
          PCPlus4D <= PCPlus4F;
        end
    end

endmodule
