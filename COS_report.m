%% Power- and Area-Optimized Digital Down Converter (DDC) Simulation
% Pure MATLAB implementation (No Fixed-Point Designer Toolbox required)
% Emulates the paper's bit-width optimizations mathematically.

clear; clc;

%% 1. Design Specifications & Fixed-Point Definition (Simulated via Scaling)
Fs_in = 200e6;                     % Input sampling frequency: 200 MHz
F_carrier = 50e6;                  % Example IF carrier frequency to mix down
Decimation_Factor = 192;           % 6-stage total decimation factor
Fs_out = Fs_in / Decimation_Factor;% Output sampling rate ~1.04 MHz

% Define Fixed-Point specifications as numbers of fractional bits (Based on Paper's Fig. 7)
FracBits_input  = 13;              % sfix14_En13 -> 13 fractional bits
FracBits_nco    = 31;              % sfix32_En31 -> 31 fractional bits
FracBits_interm = 16;              % sfix18_En16 -> 16 fractional bits

%% 2. Generate Input Stimulus (Chirp Centered around IF)
t = (0:1/Fs_in:0.001)';            % 1 ms simulation time
f0 = F_carrier - 5e6;              % Chirp start frequency
f1 = F_carrier + 5e6;              % Chirp end frequency
raw_input = chirp(t, f0, t(end), f1);

% Mathematically quantize input signal to sfix14_En13 (1 sign bit, 0 integer, 13 fraction)
input_signal = quantize_math(raw_input, FracBits_input);

%% 3. Numerically Controlled Oscillator (NCO) Simulation
% Map normalized tuning frequency
phase_increment = (F_carrier/Fs_in) * (2^32); 
phase_accumulator = 0; 

nco_cosine = zeros(size(input_signal));
nco_sine   = zeros(size(input_signal));

for k = 1:length(input_signal)
    % Update 32-bit phase accumulator with wrap-around simulation (modulo 2^32)
    phase_accumulator = mod(phase_accumulator + phase_increment, 2^32);
    
    % Map phase to normalized radian value between -pi and pi
    phase_val = phase_accumulator * (pi / (2^31));
    
    % Store mathematically quantized NCO outputs (sfix32_En31)
    nco_cosine(k) = quantize_math(cos(phase_val), FracBits_nco);
    nco_sine(k)   = quantize_math(sin(phase_val), FracBits_nco);
end

%% 4. Mixer Stage (Multiplication)
% Cast directly to optimized bit-width sfix18_En16
mix_I = zeros(size(input_signal));
mix_Q = zeros(size(input_signal));

for k = 1:length(input_signal)
    % Perform real hardware-like quantization on the products
    mix_I(k) = quantize_math(input_signal(k) * nco_cosine(k), FracBits_interm);
    mix_Q(k) = quantize_math(input_signal(k) * (-nco_sine(k)), FracBits_interm);
end

%% 5. Six-Stage Decimation Filtering Chain (Total Factor = 192)
% Decimation breakdown per stage: [3, 2, 2, 2, 4, 2]
stages = [3, 2, 2, 2, 4, 2];

% Define Lowpass FIR Coefficients for each stage (simulating the six-stages)
h1 = quantize_math(fir1(12, 1/stages(1)), FracBits_interm);
h2 = quantize_math(fir1(8,  1/stages(2)), FracBits_interm);
h3 = quantize_math(fir1(8,  1/stages(3)), FracBits_interm);
h4 = quantize_math(fir1(8,  1/stages(4)), FracBits_interm);
h5 = quantize_math(fir1(16, 1/stages(5)), FracBits_interm);
h6 = quantize_math(fir1(8,  1/stages(6)), FracBits_interm);

% Process In-phase (I) and Quadrature (Q) streams through the math-quantized 6 stages
out_I = process_6_stage_filter_math(mix_I, stages, h1, h2, h3, h4, h5, h6, FracBits_interm);
out_Q = process_6_stage_filter_math(mix_Q, stages, h1, h2, h3, h4, h5, h6, FracBits_interm);

%% 6. Analyze Output Results
complex_output = out_I + 1i*out_Q;

figure;
subplot(2,1,1);
plot(real(complex_output(1:min(500, length(complex_output)))));
title('Time-Domain Baseband Output (I-Channel) - License Free Code');
xlabel('Sample Index'); ylabel('Amplitude');
grid on;

subplot(2,1,2);
periodogram(complex_output, [], [], Fs_out, 'centered');
title('Frequency-Domain Baseband Output (1 MHz Bandwidth)');
grid on;

%% --- Core Mathematical Emulation Functions ---

% This function replaces the fixed point tool by scaling up, truncating (Floor), 
% and scaling down to enforce integer/fractional limitations cleanly.
function q_val = quantize_math(val, frac_bits)
    scaling_factor = 2^frac_bits;
    q_val = floor(val .* scaling_factor) ./ scaling_factor;
end

% Multi-rate Decimation Filtering with arithmetic quantization enforced at each loop
function out_sig = process_6_stage_filter_math(in_sig, stages, h1, h2, h3, h4, h5, h6, f_bits)
    s1 = filter(h1, 1, in_sig);   s1 = quantize_math(s1(1:stages(1):end), f_bits);
    s2 = filter(h2, 1, s1);       s2 = quantize_math(s2(1:stages(2):end), f_bits);
    s3 = filter(h3, 1, s2);       s3 = quantize_math(s3(1:stages(3):end), f_bits);
    s4 = filter(h4, 1, s3);       s4 = quantize_math(s4(1:stages(4):end), f_bits);
    s5 = filter(h5, 1, s4);       s5 = quantize_math(s5(1:stages(5):end), f_bits);
    s6 = filter(h6, 1, s5);       out_sig = quantize_math(s6(1:stages(6):end), f_bits);
end
