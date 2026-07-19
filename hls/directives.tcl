# Directives optimization script for the DDC design pipeline[cite: 1]
# Run automatically during core synthesis phases

# 1. Enforce high-throughput pipelining down to a target Initiation Interval of 1 cycle
set_directive_pipeline -II 1 "ddc_core"

# 2. Unroll internal loop architectures inside the shared process filter macro block
set_directive_unroll "process_shared_filter"

# 3. Explicitly optimize memory arrays to eliminate indexing read-port hardware bottlenecks
set_directive_array_partition -type complete -dim 0 "ddc_core" shift_reg
