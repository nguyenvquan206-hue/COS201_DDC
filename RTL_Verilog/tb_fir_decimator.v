`timescale 1ns / 1ps

// ============================================================================
// Module: FIR Decimator
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

    // Shift register delay line
    reg signed [IN_WIDTH-1:0] shift_reg [0:NUM_TAPS-1];
    
    // Coefficient Array
    reg signed [COEFF_WIDTH-1:0] coeff [0:NUM_TAPS-1];

    // Decimation counter
    integer dec_count;
    integer i;

    // Internal full-precision accumulator
    localparam ACC_WIDTH = IN_WIDTH + COEFF_WIDTH + $clog2(NUM_TAPS);
    reg signed [ACC_WIDTH-1:0] acc;

    // Load filter coefficients (13-tap symmetric low-pass filter)
    initial begin
        coeff[0]  = 16'sd120;
        coeff[1]  = 16'sd350;
        coeff[2]  = 16'sd800;
        coeff[3]  = 16'sd1500;
        coeff[4]  = 16'sd2300;
        coeff[5]  = 16'sd2900;
        coeff[6]  = 16'sd3100; // Center tap
        coeff[7]  = 16'sd2900;
        coeff[8]  = 16'sd2300;
        coeff[9]  = 16'sd1500;
        coeff[10] = 16'sd800;
        coeff[11] = 16'sd350;
        coeff[12] = 16'sd120;
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
            // Shift data into delay line
            for (i = NUM_TAPS-1; i > 0; i = i - 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end
            shift_reg[0] <= in_data;

            // Decimation Strobe Logic
            if (dec_count == DEC_FACTOR - 1) begin
                dec_count <= 0;
                
                // Compute FIR dot product
                acc = 0;
                acc = acc + (in_data * coeff[0]); // Current incoming sample
                for (i = 1; i < NUM_TAPS; i = i + 1) begin
                    acc = acc + (shift_reg[i-1] * coeff[i]);
                end
                
                // Scale down and truncate to output width
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
// Testbench: tb_fir_decimator
// ============================================================================
module tb_fir_decimator;

    parameter NUM_TAPS    = 13;
    parameter DEC_FACTOR  = 3;
    parameter IN_WIDTH    = 16;
    parameter COEFF_WIDTH = 16;
    parameter OUT_WIDTH   = 16;

    reg clk;
    reg rst_n;
    reg valid_in;
    reg signed [IN_WIDTH-1:0] in_data;

    wire valid_out;
    wire signed [OUT_WIDTH-1:0] out_data;

    // Unit Under Test (UUT)
    fir_decimator #(
        .NUM_TAPS(NUM_TAPS),
        .DEC_FACTOR(DEC_FACTOR),
        .IN_WIDTH(IN_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .OUT_WIDTH(OUT_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .in_data(in_data),
        .valid_out(valid_out),
        .out_data(out_data)
    );

    // 100 MHz Clock (10ns Period)
    always #5 clk = ~clk;

    integer k;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_fir_decimator);

        clk = 0;
        rst_n = 0;
        valid_in = 0;
        in_data = 0;

        #20;
        rst_n = 1;

        $display(" Time(ns) | VALID_IN |  IN_DATA  | VALID_OUT |  OUT_DATA ");
        $display("---------------------------------------------------------");

        // Feed step input sequence to test decimation (1 in 3 outputs produced)
        for (k = 0; k < 30; k = k + 1) begin
            @(posedge clk);
            valid_in <= 1'b1;
            in_data  <= 16'sd1000;
            
            #1;
            $display("%8t |    %1b     | %9d |     %1b     | %9d", 
                     $time, valid_in, in_data, valid_out, out_data);
        end

        @(posedge clk);
        valid_in <= 1'b0;

        #200;
        $finish;
    end

endmodule

Code module: Generic Parameterized FIR Decimator
