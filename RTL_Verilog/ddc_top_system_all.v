fir_decimator #(.NUM_TAPS(9),  .DEC_FACTOR(2)) fir_q_st6 (.clk(clk), .rst_n(rst_n), .valid_in(v_q5), .in_data(q_s5),  .valid_out(v_q6),     .out_data(out_q));

endmodule


// ============================================================================
// Testbench: tb_ddc_top
// ============================================================================
module tb_ddc_top;

    reg clk;
    reg rst_n;
    reg signed [11:0] adc_in;
    reg [31:0] phase_inc;

    wire valid_out;
    wire signed [15:0] out_i;
    wire signed [15:0] out_q;

    // Instantiate Top-Level DDC
    ddc_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_in(adc_in),
        .phase_inc(phase_inc),
        .valid_out(valid_out),
        .out_i(out_i),
        .out_q(out_q)
    );

    // 200 MHz Clock (5ns Period)
    always #2.5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_ddc_top);

        clk = 0;
        rst_n = 0;
        adc_in = 12'sd1000;
        phase_inc = 32'h4000_0000; // 50 MHz IF @ 200 MHz Clock

        #20;
        rst_n = 1;

        $display(" Time(ns) | VALID_OUT |    OUT_I   |    OUT_Q   ");
        $display("----------------------------------------------");

        // Run long enough to accommodate decimation factor (3 * 2 * 2 * 2 * 4 * 2 = 192x total decimation)
        repeat (1000) begin
            @(posedge clk);
            if (valid_out) begin
                $display("%8t |     %1b     | %10d | %10d", $time, valid_out, out_i, out_q);
            end
        end

        #100;
        $finish;
    end

endmodule

Code Final Gop lai tat ca cac module cho de thay
