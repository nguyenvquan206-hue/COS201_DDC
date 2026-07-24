// Module: nco_phase_accumulator
// 32-bit Phase Accumulator for Numerically Controlled Oscillator (NCO)

module nco_phase_accumulator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] phase_increment, // Frequency Control Word (FCW)
    output reg  [31:0] phase_acc        // 32-bit Phase accumulator output
);

    // 32-bit register automatically wraps around at 2^32
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 32'd0;
        end else begin
            phase_acc <= phase_acc + phase_increment;
        end
    end

endmodule

Test Bench:
module tb;
  reg clk=0, rst=1; wire [3:0] count;
  counter4 uut(.clk(clk),.rst(rst),.count(count));
  always #5 clk = ~clk;
  initial begin
    $dumpfile("dump.vcd"); $dumpvars(0, tb);
    #12 rst = 0;
    #200;
    $display("Final count = %0d", count);
    $finish;
  end
  always @(posedge clk)
    $display("t=%0t | count=%0d (%04b)", $time, count, count);
endmodule
