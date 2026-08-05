# Physical RTL 4-Stage Decision Tree

A reusable deterministic FPGA decision-tree inference core for AI Trader and other bounded real-time inference workloads.

## Verified contract

- Clock: **322.56 MHz** (`3.1002 ns`)
- Latency: **4 cycles** from implemented Source FDRE/Q to registered Decision FDRE/Q
- Registered latency: **12.4008 ns**
- Throughput: **1 inference per cycle** after pipeline fill
- Post-Implementation Timing Simulation: **8/8 leaves checked, 0 errors**
- Post-route timing: **WNS +1.641 ns**, **WHS +0.043 ns**, **0 failing endpoints**

## Physical pipeline

```text
Source FDRE/Q at cycle N
  -> C1 fixed feature capture
  -> C2 seven parallel signed threshold comparators
  -> C3 eight one-hot leaf equations
  -> C4 registered BUY / SELL / HOLD decision at cycle N+4
```

The core uses compile-time feature routing, bounded signed comparisons, independent one-hot leaf decode equations and a registered action encoder. Users can replace feature selection, thresholds, leaf actions and verification vectors with parameters exported from their own AI training or calibration flow.

## Evidence

### Post-Implementation Timing Simulation

![Post-Implementation Timing Simulation](./docs/post-implementation-timing-waveform.jpg?raw=1)

[Open the full-resolution waveform](./docs/post-implementation-timing-waveform.jpg?raw=1)

### Post-route device and timing paths

![Post-route device and timing paths](./docs/post-route-device-and-timing.jpg?raw=1)

[Open the full-resolution post-route evidence](./docs/post-route-device-and-timing.jpg?raw=1)

## Files

```text
deterministic_tree_4stage.sv
    Synthesizable parameterized inference core.

deterministic_tree_4stage_verify_top.sv
    Implemented Source-FDRE verification wrapper.

tb_deterministic_tree_4stage_verify_top.sv
    Default eight-leaf reference testbench.

deterministic_tree_4stage_verify_top.xdc
    322.56 MHz benchmark constraints.

create_project.tcl
    Reproducible Vivado project setup.
```

## Vivado project

Run from the Vivado Tcl Console:

```tcl
source /absolute/path/to/create_project.tcl
```

The script sets:

```text
Design Top     = deterministic_tree_4stage_verify_top
Simulation Top = tb_deterministic_tree_4stage_verify_top
```

Then run Behavioral Simulation, Synthesis, Implementation and Post-Implementation Timing Simulation.

## AI Trader integration

A typical deployment places the trained bounded model inside the current-tick FPGA datapath:

```text
Registered fixed-point features
  -> deterministic_tree_4stage
  -> registered decision
  -> hard risk gate
  -> order intent
```

Training, feature selection and parameter calibration can remain in a Python or CPU control plane. The FPGA core performs the committed inference without a current-tick CPU round trip.
