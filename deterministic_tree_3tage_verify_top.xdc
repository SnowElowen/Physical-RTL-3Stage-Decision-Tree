# SnowSakura deterministic-tree implemented source-Q verification benchmark
# Design Top: deterministic_tree_4stage_verify_top

create_clock -name core_clk_in \
    -period 3.1002 \
    -waveform {0.0000 1.5501} \
    [get_ports clk_i]

set_clock_uncertainty -setup 0.100 [get_clocks core_clk_in]
set_clock_uncertainty -hold  0.050 [get_clocks core_clk_in]

# External asynchronous reset is not part of the measured datapath.
set_false_path -from [get_ports rst_async_i]

# Observation OBUF paths are excluded; the benchmarked paths remain internal:
# source FDRE/Q -> core C1/C2/C3/C4 FDRE/D.
set_false_path -to [get_ports {
    sample_clk_o
    rst_sync_o
    source_valid_o
    source_index_o[*]
    decision_valid_o
    decision_o[*]
}]

# Benchmark-only project: no package-pin LOCs and no bitstream generation.
