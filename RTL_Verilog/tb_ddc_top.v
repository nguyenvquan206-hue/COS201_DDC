`timescale 1ns / 1ps

// ============================================================================
// Module 1: DDC NCO (Numerically Controlled Oscillator)
// ============================================================================
module ddc_nco #(
    parameter DATA_WIDTH = 12
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire [31:0]                   phase_inc,
    output reg  signed [DATA_WIDTH-1:0] nco_cos,
    output reg  signed [DATA_WIDTH-1:0] nco_sin
);

    reg [31:0] phase_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 32'd0;
        end else begin
            phase_acc <= phase_acc + phase_inc;
        end
    end

    // Use top bits of phase_acc for quadrant lookup
    wire [5:0] lut_index = phase_acc[31:26];

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
// Module 2: DDC Mixer
// ============================================================================
module ddc_mixer #(
    parameter IN_WIDTH  = 12,
    parameter NCO_WIDTH = 12,
    parameter OUT_WIDTH = 24
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire signed [IN_WIDTH-1:0]    adc_in,
    input  wire signed [NCO_WIDTH-1:0]   nco_cos,
    input  wire signed [NCO_WIDTH-1:0]   nco_sin,
    output reg  signed [OUT_WIDTH-1:0]   mix_i,
    output reg  signed [OUT_WIDTH-1:0]   mix_q
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mix_i <= {OUT_WIDTH{1'b0}};
            mix_q <= {OUT_WIDTH{1'b0}};
        end else begin
            mix_i <= adc_in * nco_cos;
          mix_q <= adc_in * nco_sin;
        end
    end

endmodule


// ============================================================================
// Top-Level Testbench: TB DDC (NCO + Mixer)
// ============================================================================
module tb_ddc_top;

    parameter DATA_WIDTH = 12;
    parameter OUT_WIDTH  = 24;

    reg clk;
    reg rst_n;
    reg [31:0] phase_inc;
    reg signed [DATA_WIDTH-1:0] adc_in;

    wire signed [DATA_WIDTH-1:0] nco_cos;
    wire signed [DATA_WIDTH-1:0] nco_sin;
    wire signed [OUT_WIDTH-1:0]  mix_i;
    wire signed [OUT_WIDTH-1:0]  mix_q;

    // Instantiate NCO
    ddc_nco #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_nco (
        .clk(clk),
        .rst_n(rst_n),
        .phase_inc(phase_inc),
        .nco_cos(nco_cos),
        .nco_sin(nco_sin)
    );

    // Instantiate Mixer
    ddc_mixer #(
        .IN_WIDTH(DATA_WIDTH),
        .NCO_WIDTH(DATA_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) u_mixer (
        .clk(clk),
        .rst_n(rst_n),
        .adc_in(adc_in),
        .nco_cos(nco_cos),
        .nco_sin(nco_sin),
        .mix_i(mix_i),
        .mix_q(mix_q)
    );

    // 100 MHz Clock (10ns period)
    always #5 clk = ~clk;

    initial begin
        // VCD Dump for Waveform tab
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_ddc_top);

        // Init Signals
        clk = 0;
        rst_n = 0;
        adc_in = 12'sd1000; // Sample ADC Input Constant / Pulse
        phase_inc = 32'd42949673; // FCW (~1 MHz @ 100 MHz Clock)

        // Reset Sequence
        #20;
        rst_n = 1;

        $display(" Time(ns) |   ADC_IN   |  NCO_COS  |  NCO_SIN  |   MIX_I   |   MIX_Q   ");
        $display("-----------------------------------------------------------------------");

        repeat (20) begin
            #50;
            $display("%8t | %10d | %9d | %9d | %9d | %9d", 
                     $time, adc_in, nco_cos, nco_sin, mix_i, mix_q);
        end

        #1000;
        $finish;
    end

endmodule

Code: Digital Quadrature Mixer
