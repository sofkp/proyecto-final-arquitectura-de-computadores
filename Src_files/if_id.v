`timescale 1ns / 1ps

module if_id(input clk, reset, en, FlushD,
             input [31:0] InstrF, PCF, PCPlus4F,
             output reg [31:0]  InstrD, PCD, PCPlus4D);

    always @(posedge clk) begin
        if (reset || FlushD) begin
          InstrD   <= 32'b0;
          PCD      <= 32'b0;
          PCPlus4D <= 32'b0;
        end else if (en) begin
          InstrD   <= InstrF;
          PCD      <= PCF;
          PCPlus4D <= PCPlus4F;
        end
    end

endmodule