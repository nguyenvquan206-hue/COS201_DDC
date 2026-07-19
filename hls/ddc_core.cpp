#include <ap_fixed.h>
#include <hls_math.h>

// Define target hardware word-lengths matching Section 4.1 of the report
typedef ap_fixed<14, 1, AP_RND, AP_SAT> data_in_t;    // sfix14_En13
typedef ap_fixed<32, 1, AP_RND, AP_SAT> nco_out_t;    // sfix32_En31[cite: 1]
typedef ap_fixed<18, 2, AP_TRN, AP_SAT> interm_t;     // sfix18_En16 (floor truncation)[cite: 1]

// Compact sample Lowpass FIR filter coefficients scaled to sfix18_En16[cite: 1]
const interm_t h1[3] = {0.25, 0.5, 0.25}; // Stage 1 (Decimate by 3)[cite: 1]
const interm_t h2[3] = {0.3, 0.4, 0.3};   // Stage 2 (Decimate by 2)[cite: 1]
const interm_t h3[3] = {0.3, 0.4, 0.3};   // Stage 3 (Decimate by 2)[cite: 1]
const interm_t h4[3] = {0.3, 0.4, 0.3};   // Stage 4 (Decimate by 2)[cite: 1]
const interm_t h5[3] = {0.2, 0.6, 0.2};   // Stage 5 (Decimate by 4)[cite: 1]
const interm_t h6[3] = {0.3, 0.4, 0.3};   // Stage 6 (Decimate by 2)[cite: 1]

// Shared single-branch filter function to optimize hardware area[cite: 1]
interm_t process_shared_filter(interm_t sample_in, interm_t coeffs[3], int stage_idx) {
    static interm_t shift_reg[6][3] = {0}; // Localized array mapping shift registers per stage
    #pragma HLS ARRAY_PARTITION variable=shift_reg complete dim=0
    
    // Shift register logic
    shift_reg[stage_idx][2] = shift_reg[stage_idx][1];
    shift_reg[stage_idx][1] = shift_reg[stage_idx][0];
    shift_reg[stage_idx][0] = sample_in;
    
    // Compute MAC (Multiply-Accumulate) with low-cost floor truncation bias[cite: 1]
    return (interm_t)(shift_reg[stage_idx][0] * coeffs[0] + 
                      shift_reg[stage_idx][1] * coeffs[1] + 
                      shift_reg[stage_idx][2] * coeffs[2]);
}

void ddc_core(data_in_t signal_in, interm_t &out_I, interm_t &out_Q, bool &valid_out) {
    // Port mappings for physical FPGA streaming
    #pragma HLS INTERFACE ap_vld port=signal_in
    #pragma HLS INTERFACE ap_vld port=out_I
    #pragma HLS INTERFACE ap_vld port=out_Q
    #pragma HLS INTERFACE ap_vld port=valid_out
    
    // Master tuning parameters[cite: 1]
    // 50 MHz carrier over 200 MHz sample clock = normalized tuning value 0.25[cite: 1]
    const ap_uint<32> phase_increment = 1073741824; // (50MHz / 200MHz) * 2^32[cite: 1]
    static ap_uint<32> phase_accumulator = 0;
    
    // Global downsampling decimation loop counter trackers
    static int count1 = 0, count2 = 0, count3 = 0, count4 = 0, count5 = 0, count6 = 0;
    
    valid_out = false;
    
    // --- 1. Numerically Controlled Oscillator (NCO) Stage ---
    phase_accumulator += phase_increment; // Native register overflow wrap-around[cite: 1]
    float radians = (float)phase_accumulator * (3.14159265f / 2147483648.0f);[cite: 1]
    
    nco_out_t local_cos = hls::cos(radians);[cite: 1]
    nco_out_t local_sin = hls::sin(radians);[cite: 1]
    
    // --- 2. Mixer Stage ---
    interm_t mix_I = (interm_t)(signal_in * local_cos);[cite: 1]
    interm_t mix_Q = (interm_t)(signal_in * (-local_sin));[cite: 1]
    
    // --- 3. Shared Decimation Pipeline[cite: 1] ---
    // Stage 1 (Decimate by 3)[cite: 1]
    interm_t f1_I = process_shared_filter(mix_I, (interm_t*)h1, 0);
    interm_t f1_Q = process_shared_filter(mix_Q, (interm_t*)h1, 0);
    count1++;
    
    if (count1 == 3) {[cite: 1]
        count1 = 0;
        // Stage 2 (Decimate by 2)[cite: 1]
        interm_t f2_I = process_shared_filter(f1_I, (interm_t*)h2, 1);
        interm_t f2_Q = process_shared_filter(f1_Q, (interm_t*)h2, 1);
        count2++;
        
        if (count2 == 2) {[cite: 1]
            count2 = 0;
            // Stage 3 (Decimate by 2)[cite: 1]
            interm_t f3_I = process_shared_filter(f2_I, (interm_t*)h3, 2);
            interm_t f3_Q = process_shared_filter(f2_Q, (interm_t*)h3, 2);
            count3++;
            
            if (count3 == 2) {[cite: 1]
                count3 = 0;
                // Stage 4 (Decimate by 2)[cite: 1]
                interm_t f4_I = process_shared_filter(f3_I, (interm_t*)h4, 3);
                interm_t f4_Q = process_shared_filter(f3_Q, (interm_t*)h4, 3);
                count4++;
                
                if (count4 == 2) {[cite: 1]
                    count4 = 0;
                    // Stage 5 (Decimate by 4)[cite: 1]
                    interm_t f5_I = process_shared_filter(f4_I, (interm_t*)h5, 4);
                    interm_t f5_Q = process_shared_filter(f4_Q, (interm_t*)h5, 4);
                    count5++;
                    
                    if (count5 == 4) {[cite: 1]
                        count5 = 0;
                        // Stage 6 (Decimate by 2)[cite: 1]
                        out_I = process_shared_filter(f5_I, (interm_t*)h6, 5);
                        out_Q = process_shared_filter(f5_Q, (interm_t*)h6, 5);
                        count6++;
                        
                        if (count6 == 2) {[cite: 1]
                            count6 = 0;
                            valid_out = true; // High-rate output token ready[cite: 1]
                        }
                    }
                }
            }
        }
    }
}
