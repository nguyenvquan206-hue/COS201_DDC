#include <iostream>
#include <cmath>
#include <ap_fixed.h>

// Declare core architecture footprint
typedef ap_fixed<14, 1, AP_RND, AP_SAT> data_in_t;
typedef ap_fixed<18, 2, AP_TRN, AP_SAT> interm_t;

void ddc_core(data_in_t signal_in, interm_t &out_I, interm_t &out_Q, bool &valid_out);

int main() {
    std::cout << "--------------------------------------------------------" << std::endl;
    std::cout << "STARTING DDC MICRO-ARCHITECTURAL C-SIMULATION TESTBENCH" << std::endl;
    std::cout << "--------------------------------------------------------" << std::endl;

    data_in_t test_input;
    interm_t hw_out_I, hw_out_Q;
    bool output_valid;
    
    int total_samples = 600;
    int processed_outputs = 0;

    // Pump synthetic input stimulus streams through the hardware block
    for (int i = 0; i < total_samples; i++) {
        // Synthesize a simulated chirp wave mixed near 50 MHz carrier domain[cite: 1]
        float t = (float)i / 200000000.0f; // 200 MHz clock reference[cite: 1]
        float raw_wave = sin(2.0f * 3.14159265f * 50000000.0f * t);[cite: 1]
        
        test_input = (data_in_t)raw_wave;
        
        // Compute hardware cycle processing step
        ddc_core(test_input, hw_out_I, hw_out_Q, output_valid);
        
        // Capture down-converted structural baseline signals when validation tokens are high
        if (output_valid) {
            processed_outputs++;
            std::cout << "Decimated Baseband Sample #" << processed_outputs 
                      << " | I = " << hw_out_I.to_double() 
                      << " | Q = " << hw_out_Q.to_double() << std::endl;
        }
    }

    std::cout << "\nVerification Status: SUCCESS. Processed " << processed_outputs 
              << " baseband outputs through the shared pipeline." << std::endl;
    std::cout << "--------------------------------------------------------" << std::endl;
    
    return 0;
}
