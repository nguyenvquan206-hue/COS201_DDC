%% Verification Wrapper for DDC Implementation
% This script isolates Golden_model and COS_report to capture outputs
% cleanly and calculate the root-mean-square (RMS) quantization error.

clear; clc; close all;

%% 1. Execute and Capture Golden Reference Model
fprintf('Running Golden Reference Model (64-bit Double Precision)... \n');
baseline = run_script_isolated('Golden_model.m');

%% 2. Execute and Capture Bit-Width Optimized Model
fprintf('Running Bit-Width Optimized Model (COS_report)... \n');
optimized_result = run_script_isolated('COS_report.m');

%% 3. Calculate Quantization Error Metrics
% Align lengths if there are minor filter startup delay variations
len = min(length(baseline), length(optimized_result));
baseline = baseline(1:len);
optimized_result = optimized_result(1:len);

% Compute absolute error signal
error_signal = baseline - optimized_result;

% Calculate Root Mean Square (RMS) Error Percentage
rms_golden = sqrt(mean(abs(baseline).^2));
rms_error  = sqrt(mean(abs(error_signal).^2));
pct_error  = (rms_error / rms_golden) * 100;

%% 4. Display Results and Verification Status
fprintf('\n================ VERIFICATION RESULTS ================ \n');
fprintf('Measured RMS Quantization Error: %.4f%%\n', pct_error);

if pct_error < 1.0
    fprintf('Status: SUCCESS (Error is under the paper''s 1%% threshold)[cite: 1]\n');
else
    fprintf('Status: WARNING (Error exceeds 1%% threshold. Check fractional bit truncation.)\n');
end
fprintf('====================================================== \n');

%% 5. Plot Superimposed Comparison (Replicating Paper's Figure 10)
figure('Name', 'DDC Quantization Verification');
plot(real(baseline(1:min(300, len))), 'b-', 'LineWidth', 1.5); hold on;
plot(real(optimized_result(1:min(300, len))), 'r--', 'LineWidth', 1.2);
title('Time-Domain Output Comparison (Superimposed)[cite: 1]');
xlabel('Sample Index'); ylabel('Amplitude');
legend('Golden Model (Double Precision)', 'Optimized Model (COS\_report)', 'Location', 'best');
grid on;

%% --- Helper Function to Isolate Script Workspaces ---
function out_data = run_script_isolated(script_name)
    if ~exist(script_name, 'file')
        error('%s not found in the current directory.', script_name);
    end
    
    % Run script inside a localized function workspace
    run(script_name);
    
    % Dynamically hunt for the array containing the complex output signal
    vars = whos;
    captured_var = '';
    
    % Look for the largest complex double array or common names
    for i = 1:length(vars)
        if vars(i).complex && strcmp(vars(i).class, 'double') && vars(i).bytes > 100
            captured_var = vars(i).name;
            break;
        end
    end
    
    % Fallback checks if the array isn't explicitly flagged as complex yet
    if isempty(captured_var) && exist('complex_output', 'var')
        captured_var = 'complex_output';
    elseif isempty(captured_var) && exist('golden_complex_output', 'var')
        captured_var = 'golden_complex_output';
        end
    
    if isempty(captured_var)
        error('Could not automatically capture the output signal array from %s. Ensure the script generates a vector array.', script_name);
    end
    
    % Extract the data out to the main wrapper workspace
    out_data = eval(captured_var);
end
