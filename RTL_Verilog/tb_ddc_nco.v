`timescale 1ns / 1ps

// ============================================================================
// RTL Module: DDC NCO (Numerically Controlled Oscillator)
// ============================================================================
module ddc_nco #(
    parameter DATA_WIDTH = 12
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [31:0]            phase_inc,
    output reg  signed [DATA_WIDTH-1:0] nco_cos,
    output reg  signed [DATA_WIDTH-1:0] nco_sin
);

    // 32-bit Phase Accumulator (accessed by testbench as uut.phase_acc)
    reg [31:0] phase_acc;

    // Phase Accumulator Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 32'd0;
        end else begin
            phase_acc <= phase_acc + phase_inc;
        end
    end

    // Use top bits of phase_acc to index lookup tables (6-bit lookup table)
    wire [5:0] lut_index = phase_acc[31:26];

    // Simple Sine/Cosine Generation via ROM Lookup (64 steps)
    // Scaled for signed DATA_WIDTH output range
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nco_cos <= {DATA_WIDTH{1'b0}};
            nco_sin <= {DATA_WIDTH{1'b0}};
        end else begin
            case (lut_index[5:4])
                2'b00: begin // Quadrant 1
                    nco_cos <=  ( (2**(DATA_WIDTH-1)-1) - (lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16) );
                    nco_sin <=  ( lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16 );
                end
                2'b01: begin // Quadrant 2
                    nco_cos <= -( lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16 );
                    nco_sin <=  ( (2**(DATA_WIDTH-1)-1) - (lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16) );
                end
                2'b10: begin // Quadrant 3
                    nco_cos <= -( (2**(DATA_WIDTH-1)-1) - (lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16) );
                    nco_sin <= -( lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16 );
                end
                2'b11: begin // Quadrant 4
                    nco_cos <=  ( lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16 );
                    nco_sin <= -( (2**(DATA_WIDTH-1)-1) - (lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16) );
                end
            endcase
        end
    end

endmodule


// ============================================================================
// Testbench
// ============================================================================
module tb_ddc_nco;

    parameter DATA_WIDTH = 12;

    reg clk;
    reg rst_n;
    reg [31:0] phase_inc;

    wire signed [DATA_WIDTH-1:0] nco_cos;
    wire signed [DATA_WIDTH-1:0] nco_sin;

    // Instantiate the Unit Under Test (UUT)
    ddc_nco #(
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .phase_inc(phase_inc),
        .nco_cos(nco_cos),
        .nco_sin(nco_sin)
    );
  // 100 MHz Clock Generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        // Setup Waveform Dump for EPWave / GTKWave
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_ddc_nco);

        // Initialize Inputs
        clk = 0;
        rst_n = 0;
        
        // Frequency Control Word (FCW):
        // F_out = (phase_inc * F_clk) / 2^32
        // Example: phase_inc = 42949673 (~1 MHz output at 100 MHz clock)
        phase_inc = 32'd42949673;

        // Apply Reset
        #20;
        rst_n = 1;

        // Print initial sample headers
        $display(" Time(ns) | Phase_Acc   | NCO_COS | NCO_SIN");
        $display("-------------------------------------------");
        
        // Monitor values every 50ns in terminal
        repeat (20) begin
            #50;
            $display("%8t | %11d | %7d | %7d", $time, uut.phase_acc, nco_cos, nco_sin);
        end

        // Run simulation for 2000ns to see a full sine period
        #2000;
        $finish;
    end

endmodule
