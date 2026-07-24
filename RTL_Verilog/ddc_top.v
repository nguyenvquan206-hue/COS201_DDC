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

    wire [5:0] lut_index = phase_acc[31:26];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nco_cos <= {DATA_WIDTH{1'b0}};
            nco_sin <= {DATA_WIDTH{1'b0}};
        end else begin
            case (lut_index[5:4])
                2'b00: begin
                    nco_cos <=  ( (2**(DATA_WIDTH-1)-1) - (lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16) );
                    nco_sin <=  ( lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16 );
                end
                2'b01: begin
                    nco_cos <= -( lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16 );
                    nco_sin <=  ( (2**(DATA_WIDTH-1)-1) - (lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16) );
                end
                2'b10: begin
                    nco_cos <= -( (2**(DATA_WIDTH-1)-1) - (lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16) );
                    nco_sin <= -( lut_index[3:0] * (2**(DATA_WIDTH-1)-1) / 16 );
                end
                2'b11: begin
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
// Module 3: Generic Parametric FIR Decimator
// ============================================================================
module fir_decimator #(
    parameter NUM_TAPS    = 13,
    parameter DEC_FACTOR  = 3,
    parameter IN_WIDTH    = 16,
    parameter COEFF_WIDTH = 16,
    parameter OUT_WIDTH   = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       valid_in,
    input  wire signed [IN_WIDTH-1:0] in_data,
    output reg                        valid_out,
    output reg  signed [OUT_WIDTH-1:0] out_data
);

    reg signed [IN_WIDTH-1:0] shift_reg [0:NUM_TAPS-1];
    reg signed [COEFF_WIDTH-1:0] coeff [0:NUM_TAPS-1];

    integer dec_count;
    integer i;

    localparam ACC_WIDTH = IN_WIDTH + COEFF_WIDTH + $clog2(NUM_TAPS);
    reg signed [ACC_WIDTH-1:0] acc;

    // Simple symmetric low-pass filter impulse response approximation
    initial begin
        for (i = 0; i < NUM_TAPS; i = i + 1) begin
            coeff[i] = 16'sd1000 + (16'sd2000 * i / NUM_TAPS);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_count <= 0;
            valid_out <= 1'b0;
            out_data  <= {OUT_WIDTH{1'b0}};
            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                shift_reg[i] <= {IN_WIDTH{1'b0}};
            end
        end else if (valid_in) begin
            for (i = NUM_TAPS-1; i > 0; i = i - 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end
            shift_reg[0] <= in_data;

            if (dec_count == DEC_FACTOR - 1) begin
                dec_count <= 0;
                
                acc = 0;
                acc = acc + (in_data * coeff[0]);
                for (i = 1; i < NUM_TAPS; i = i + 1) begin
                    acc = acc + (shift_reg[i-1] * coeff[i]);
                end
                
                out_data  <= acc[ACC_WIDTH-2 -: OUT_WIDTH]; 
                valid_out <= 1'b1;
            end else begin
                dec_count <= dec_count + 1;
                valid_out <= 1'b0;
            end
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule


// ============================================================================
// Top-Level Module: DDC Top (NCO + Mixer + 6-stage I/Q Decimation Chain)
// ============================================================================
module ddc_top (
    input  wire                 clk,          // 200 MHz Master Clock
    input  wire                 rst_n,
    input  wire signed [11:0]   adc_in,       // 12-bit Input Stimulus
    input  wire [31:0]          phase_inc,    // FCW = (50MHz / 200MHz) * 2^32 = 0x4000_0000
    
    // Decimated Output (~1.04 MHz rate)
    output wire                 valid_out,
    output wire signed [15:0]   out_i,
    output wire signed [15:0]   out_q
);
  // --- 1. NCO Signals ---
    wire signed [11:0] nco_cos;
    wire signed [11:0] nco_sin;

    ddc_nco #(.DATA_WIDTH(12)) u_nco (
        .clk(clk),
        .rst_n(rst_n),
        .phase_inc(phase_inc),
        .nco_cos(nco_cos),
        .nco_sin(nco_sin)
    );

    // --- 2. Mixer Stage ---
    wire signed [23:0] mix_i_full, mix_q_full;

    ddc_mixer #(
        .IN_WIDTH(12),
        .NCO_WIDTH(12),
        .OUT_WIDTH(24)
    ) u_mixer (
        .clk(clk),
        .rst_n(rst_n),
        .adc_in(adc_in),
        .nco_cos(nco_cos),
        .nco_sin(nco_sin),
        .mix_i(mix_i_full),
        .mix_q(mix_q_full)
    );

    // Truncate mixer output for FIR Stage 1 input (24-bit -> 16-bit)
    wire signed [15:0] mix_i = mix_i_full[22:7];
    wire signed [15:0] mix_q = mix_q_full[22:7];

    // --- 3. Six-Stage Decimation Chain (I-Channel) ---
    wire [15:0] i_s1, i_s2, i_s3, i_s4, i_s5;
    wire        v_i1, v_i2, v_i3, v_i4, v_i5;

    fir_decimator #(.NUM_TAPS(13), .DEC_FACTOR(3)) fir_i_st1 (.clk(clk), .rst_n(rst_n), .valid_in(1'b1), .in_data(mix_i), .valid_out(v_i1), .out_data(i_s1));
    fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_i_st2 (.clk(clk), .rst_n(rst_n), .valid_in(v_i1), .in_data(i_s1),  .valid_out(v_i2), .out_data(i_s2));
    fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_i_st3 (.clk(clk), .rst_n(rst_n), .valid_in(v_i2), .in_data(i_s2),  .valid_out(v_i3), .out_data(i_s3));
    fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_i_st4 (.clk(clk), .rst_n(rst_n), .valid_in(v_i3), .in_data(i_s3),  .valid_out(v_i4), .out_data(i_s4));
    fir_decimator #(.NUM_TAPS(17), .DEC_FACTOR(4)) fir_i_st5 (.clk(clk), .rst_n(rst_n), .valid_in(v_i4), .in_data(i_s4),  .valid_out(v_i5), .out_data(i_s5));
    fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_i_st6 (.clk(clk), .rst_n(rst_n), .valid_in(v_i5), .in_data(i_s5),  .valid_out(valid_out), .out_data(out_i));

    // --- 4. Six-Stage Decimation Chain (Q-Channel) ---
    wire [15:0] q_s1, q_s2, q_s3, q_s4, q_s5;
    wire        v_q1, v_q2, v_q3, v_q4, v_q5, v_q6;

    fir_decimator #(.NUM_TAPS(13), .DEC_FACTOR(3)) fir_q_st1 (.clk(clk), .rst_n(rst_n), .valid_in(1'b1), .in_data(mix_q), .valid_out(v_q1), .out_data(q_s1));
    fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_q_st2 (.clk(clk), .rst_n(rst_n), .valid_in(v_q1), .in_data(q_s1),  .valid_out(v_q2), .out_data(q_s2));
    fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_q_st3 (.clk(clk), .rst_n(rst_n), .valid_in(v_q2), .in_data(q_s2),  .valid_out(v_q3), .out_data(q_s3));
    fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_q_st4 (.clk(clk), .rst_n(rst_n), .valid_in(v_q3), .in_data(q_s3),  .valid_out(v_q4), .out_data(q_s4));
    fir_decimator #(.NUM_TAPS(17), .DEC_FACTOR(4)) fir_q_st5 (.clk(clk), .rst_n(rst_n), .valid_in(v_q4), .in_data(q_s4),  .valid_out(v_q5), .out_data(q_s5));
