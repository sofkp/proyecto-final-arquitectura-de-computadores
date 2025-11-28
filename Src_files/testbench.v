module testbench();
  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;
  
  // instantiate device to be tested
  top dut(
    .clk(clk), 
    .reset(reset), 
    .WriteData(WriteData), 
    .DataAdr(DataAdr), 
    .MemWrite(MemWrite)
  );

  // initialize test
    initial begin
      reset = 1;
      #50;
      reset = 0;
      #100000;
      $finish;
    end



  // generate clock to sequence tests
  always begin
    clk = 1;
    # 15000; clk = 0; # 15000;
  end


  // check results
  
endmodule