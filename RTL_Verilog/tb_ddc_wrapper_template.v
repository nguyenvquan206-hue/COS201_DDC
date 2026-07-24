module ddc_top (
    input wire clk,
    input wire rst,
    input wire signed [15:0] in_data,
    output reg signed [15:0] out_data
);

    // Your Bit-Width Optimized DDC logic here
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_data <= 16'd0;
        end else begin
            // Processing logic...
        end
    end

endmodule

Test Bench:
`timescale 1ns/1ps

module tb;
    reg clk;
    reg rst;
    reg signed [15:0] in_data;
    wire signed [15:0] out_data;

    // Instantiate your DDC module
    ddc_top uut (
        .clk(clk),
        .rst(rst),
        .in_data(in_data),
        .out_data(out_data)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        // REQUIRED FOR ECRIONIX WAVEFORM VIEWER:
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);

        clk = 0;
        rst = 1;
        in_data = 0;

        #20 rst = 0;

        // Apply test stimuli
        #10 in_data = 16'sd1000;
        #10 in_data = 16'sd2000;
        #10 in_data = -16'sd1500;

        #100 $finish;
    end

    // Monitor output in the Console tab
    initial begin
        $monitor("Time=%0t | in_data=%d | out_data=%d", $time, in_data, out_data);
    end
endmodule
