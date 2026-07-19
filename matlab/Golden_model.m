%% Ideal Golden Model - Double-Precision Floating-Point DDC Simulation
% Serves as the unquantized mathematical reference baseline.

Fs_in = 200e6;                     
F_carrier = 50e6;                  
Decimation_Factor = 192;           
Fs_out = Fs_in / Decimation_Factor;

%% 1. Generate Ideal Input Stimulus
t = (0:1/Fs_in:0.001)';            
f0 = F_carrier - 5e6;              
f1 = F_carrier + 5e6;              
golden_input = chirp(t, f0, t(end), f1); % No quantization applied here

%% 2. Ideal NCO & Mixing Stage
nco_phase = (0:length(golden_input)-1)' * (2*pi*F_carrier/Fs_in);
mix_I_ideal = golden_input .* cos(nco_phase);
mix_Q_ideal = golden_input .* (-sin(nco_phase));

%% 3. Ideal 6-Stage Decimation Filtering Chain
stages = [3, 2, 2, 2, 4, 2];

% Generate ideal unquantized coefficients
h1 = fir1(12, 1/stages(1)); h2 = fir1(8, 1/stages(2));
h3 = fir1(8, 1/stages(3));  h4 = fir1(8, 1/stages(4));
h5 = fir1(16, 1/stages(5)); h6 = fir1(8, 1/stages(6));

% Process data through standard unquantized filters
s1 = filter(h1, 1, mix_I_ideal);   s1 = s1(1:stages(1):end);
s2 = filter(h2, 1, s1);           s2 = s2(1:stages(2):end);
s3 = filter(h3, 1, s2);           s3 = s3(1:stages(3):end);
s4 = filter(h4, 1, s3);           s4 = s4(1:stages(4):end);
s5 = filter(h5, 1, s4);           s5 = s5(1:stages(5):end);
s6 = filter(h6, 1, s5);           golden_out_I = s6(1:stages(6):end);

% Process Q channel
s1_q = filter(h1, 1, mix_Q_ideal); s1_q = s1_q(1:stages(1):end);
s2_q = filter(h2, 1, s1_q);       s2_q = s2_q(1:stages(2):end);
s3_q = filter(h3, 1, s2_q);       s3_q = s3_q(1:stages(3):end);
s4_q = filter(h4, 1, s3_q);       s4_q = s4_q(1:stages(4):end);
s5_q = filter(h5, 1, s4_q);       s5_q = s5_q(1:stages(5):end);
s6_q = filter(h6, 1, s5_q);       golden_out_Q = s6_q(1:stages(6):end);

% Create the final complex output signal array for the wrapper to hunt down
golden_complex_output = golden_out_I + 1i*golden_out_Q;
