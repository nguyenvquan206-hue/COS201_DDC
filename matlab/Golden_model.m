%% Golden Reference Model: Digital Down Converter (DDC) Simulation
% Pure MATLAB implementation using Double-Precision Floating-Point.
% This serves as the ideal baseline to calculate quantization loss.

%% 1. Golden Design Specifications
Fs_in = 200e6;                      % Input sampling frequency: 200 MHz
F_carrier = 50e6;                   % IF carrier frequency to mix down
Decimation_Factor = 192;            % 6-stage total decimation factor
Fs_out = Fs_in / Decimation_Factor; % Baseband output sampling rate (~1.04 MHz)

%% 2. Ideal Input Stimulus Generation (Double Precision)
t = (0:1/Fs_in:0.001)';             % 1 ms simulation time
f0 = F_carrier - 5e6;               % Chirp start frequency
f1 = F_carrier + 5e6;               % Chirp end frequency
golden_input = chirp(t, f0, t(end), f1); % 64-bit float by default

%% 3. Ideal Oscillator (NCO) Simulation
phase = 2 * pi * F_carrier * t;
golden_nco_cos = cos(phase);
golden_nco_sin = sin(phase);

%% 4. Ideal Mixer Stage
golden_mix_I = golden_input .* golden_nco_cos;
golden_mix_Q = golden_input .* (-golden_nco_sin);

%% 5. Ideal Six-Stage Decimation Filtering Chain
stages = [3, 2, 2, 2, 4, 2];

% Define ideal filter coefficients using double-precision float arrays
h1 = fir1(12, 1/stages(1));
h2 = fir1(8,  1/stages(2));
h3 = fir1(8,  1/stages(3));
h4 = fir1(8,  1/stages(4));
h5 = fir1(16, 1/stages(5));
h6 = fir1(8,  1/stages(6));

% Pass I and Q through the multi-rate filtering network without truncation
golden_out_I = process_6_stage_golden(golden_mix_I, stages, h1, h2, h3, h4, h5, h6);
golden_out_Q = process_6_stage_golden(golden_mix_Q, stages, h1, h2, h3, h4, h5, h6);

%% 6. Compile Final Output Array for Verification Wrapper
golden_complex_output = golden_out_I + 1i*golden_out_Q;

%% --- Core Double-Precision Emulation Function ---
function out_sig = process_6_stage_golden(in_sig, stages, h1, h2, h3, h4, h5, h6)
    s1 = filter(h1, 1, in_sig);   s1_dec = s1(1:stages(1):end);
    s2 = filter(h2, 1, s1_dec);   s2_dec = s2(1:stages(2):end);
    s3 = filter(h3, 1, s2_dec);   s3_dec = s3(1:stages(3):end);
    s4 = filter(h4, 1, s3_dec);   s4_dec = s4(1:stages(4):end);
    s5 = filter(h5, 1, s4_dec);   s5_dec = s5(1:stages(5):end);
    s6 = filter(h6, 1, s5_dec);   out_sig = s6(1:stages(6):end);
end
