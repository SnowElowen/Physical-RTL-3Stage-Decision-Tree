# Physical RTL 4-Stage Decision Tree

A reusable deterministic FPGA decision-tree inference core for AI Trader and other bounded real-time inference workloads.

The design accepts four signed 16-bit fixed-point features, evaluates seven parallel threshold nodes, resolves one of eight leaves, and emits a registered `HOLD` / `BUY` / `SELL` decision.

## Timing contract

The verified physical contract is measured from an implemented upstream Source `FDRE/Q` boundary to the registered decision `FDRE/Q` boundary:

```text
Source FDRE/Q at cycle N
  -> C1 feature capture
  -> C2 parallel signed threshold comparison
  -> C3 one-hot leaf decode
  -> C4 registered action encode at cycle N+4
```

At 322.56 MHz:

```text
Clock period: 3.1002 ns
Latency:      4 cycles = 12.4008 ns
Throughput:   1 inference per cycle after pipeline fill
```

This is a four-cycle registered-source-to-registered-output contract. Counting only from the C1 sampling edge to the C4 output edge gives three elapsed clock periods across four registered stages.

## Architecture

```text
4 x signed 16-bit feature inputs
  -> 64 FDRE feature capture
  -> 7 parallel signed threshold comparators
  -> 8 independent 3-input one-hot leaf equations
  -> constant-folded BUY / SELL action encoder
  -> registered 2-bit decision output
```

The fast datapath contains no runtime feature selector, dynamic part-select, barrel shifter, FIFO, AXI fabric, BRAM lookup, variable iteration, or HLS scheduler. `NODE*_FEATURE`, `NODE*_THRESHOLD`, and `LEAF*_ACTION` are compile-time parameters.

## Files

- `deterministic_tree_4stage.sv` — reusable synthesizable inference core
- `deterministic_tree_4stage_verify_top.sv` — implemented Source-FDRE verification wrapper
- `tb_deterministic_tree_4stage_verify_top.sv` — default eight-leaf self-checking testbench
- `deterministic_tree_4stage_verify_top.xdc` — 322.56 MHz benchmark constraints
- `create_project.tcl` — creates a clean Vivado 2022.2 project for ZU15EG

## Use it for another AI tree

Modify the core parameters:

```systemverilog
NODE0_FEATURE
NODE1_FEATURE
...
NODE6_FEATURE

NODE0_THRESHOLD
NODE1_THRESHOLD
...
NODE6_THRESHOLD

LEAF0_ACTION
LEAF1_ACTION
...
LEAF7_ACTION
```

Feature indices select one of the four fixed feature lanes at elaboration time. Thresholds are signed 16-bit fixed-point values. Leaf action encoding is:

```text
2'b00 = HOLD
2'b01 = BUY
2'b10 = SELL
2'b11 = reserved
```

Replace the default vectors in `deterministic_tree_4stage_verify_top.sv` and the expected actions in the testbench when adapting the tree.

## Reproduce the verification

From the Vivado Tcl Console:

```tcl
source F:/path/to/Physical-RTL-4Stage-Decision-Tree/create_project.tcl
```

Correct project tops:

```text
Design Top     = deterministic_tree_4stage_verify_top
Simulation Top = tb_deterministic_tree_4stage_verify_top
```

Run:

```text
Behavioral Simulation
Synthesis
Implementation
Post-Implementation Timing Simulation
```

Expected simulator result:

```text
PASS: 8/8 leaves matched the exact four-cycle source-Q contract
Latency = 4 cycles x 3.1002 ns = 12.4008 ns
```

## Target

- Device: AMD/Xilinx Zynq UltraScale+ `xczu15eg-ffvb1156-2-i`
- Tool: Vivado 2022.2
- Benchmark clock: 322.56 MHz
