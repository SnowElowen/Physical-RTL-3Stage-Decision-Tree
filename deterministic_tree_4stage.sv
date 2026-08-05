`timescale 1ps / 1ps
`default_nettype none

module deterministic_tree_4stage #(
    parameter int unsigned NODE0_FEATURE = 0,
    parameter int unsigned NODE1_FEATURE = 1,
    parameter int unsigned NODE2_FEATURE = 1,
    parameter int unsigned NODE3_FEATURE = 2,
    parameter int unsigned NODE4_FEATURE = 2,
    parameter int unsigned NODE5_FEATURE = 3,
    parameter int unsigned NODE6_FEATURE = 3,

    parameter logic signed [15:0] NODE0_THRESHOLD = 16'sd100,
    parameter logic signed [15:0] NODE1_THRESHOLD = -16'sd20,
    parameter logic signed [15:0] NODE2_THRESHOLD = 16'sd30,
    parameter logic signed [15:0] NODE3_THRESHOLD = 16'sd5,
    parameter logic signed [15:0] NODE4_THRESHOLD = 16'sd15,
    parameter logic signed [15:0] NODE5_THRESHOLD = -16'sd5,
    parameter logic signed [15:0] NODE6_THRESHOLD = 16'sd25,

    parameter logic [1:0] LEAF0_ACTION = 2'b00,
    parameter logic [1:0] LEAF1_ACTION = 2'b10,
    parameter logic [1:0] LEAF2_ACTION = 2'b10,
    parameter logic [1:0] LEAF3_ACTION = 2'b00,
    parameter logic [1:0] LEAF4_ACTION = 2'b00,
    parameter logic [1:0] LEAF5_ACTION = 2'b01,
    parameter logic [1:0] LEAF6_ACTION = 2'b01,
    parameter logic [1:0] LEAF7_ACTION = 2'b00
) (
    input  wire               clk_i,
    input  wire               rst_i,
    input  wire               feature_valid_i,
    input  wire signed [15:0] feature0_i,
    input  wire signed [15:0] feature1_i,
    input  wire signed [15:0] feature2_i,
    input  wire signed [15:0] feature3_i,
    output logic              decision_valid_o,
    output logic [1:0]        decision_o
);

    localparam logic [1:0] ACTION_BUY  = 2'b01;
    localparam logic [1:0] ACTION_SELL = 2'b10;

    localparam logic [7:0] BUY_MASK = {
        (LEAF7_ACTION == ACTION_BUY),
        (LEAF6_ACTION == ACTION_BUY),
        (LEAF5_ACTION == ACTION_BUY),
        (LEAF4_ACTION == ACTION_BUY),
        (LEAF3_ACTION == ACTION_BUY),
        (LEAF2_ACTION == ACTION_BUY),
        (LEAF1_ACTION == ACTION_BUY),
        (LEAF0_ACTION == ACTION_BUY)
    };

    localparam logic [7:0] SELL_MASK = {
        (LEAF7_ACTION == ACTION_SELL),
        (LEAF6_ACTION == ACTION_SELL),
        (LEAF5_ACTION == ACTION_SELL),
        (LEAF4_ACTION == ACTION_SELL),
        (LEAF3_ACTION == ACTION_SELL),
        (LEAF2_ACTION == ACTION_SELL),
        (LEAF1_ACTION == ACTION_SELL),
        (LEAF0_ACTION == ACTION_SELL)
    };

    initial begin : p_parameter_contract
        if (NODE0_FEATURE > 3 || NODE1_FEATURE > 3 || NODE2_FEATURE > 3 ||
            NODE3_FEATURE > 3 || NODE4_FEATURE > 3 || NODE5_FEATURE > 3 ||
            NODE6_FEATURE > 3) begin
            $error("Every NODE*_FEATURE parameter must be in range 0..3");
        end

        if ((LEAF0_ACTION == 2'b11) || (LEAF1_ACTION == 2'b11) ||
            (LEAF2_ACTION == 2'b11) || (LEAF3_ACTION == 2'b11) ||
            (LEAF4_ACTION == 2'b11) || (LEAF5_ACTION == 2'b11) ||
            (LEAF6_ACTION == 2'b11) || (LEAF7_ACTION == 2'b11)) begin
            $error("Leaf action 2'b11 is reserved and must not be used");
        end
    end

    logic signed [15:0] feature_q [0:3];
    logic [6:0] compare_q;
    logic [7:0] leaf_q;
    logic valid_c1_q;
    logic valid_c2_q;
    logic valid_c3_q;

    // C1: 64 FDRE feature capture.
    always_ff @(posedge clk_i) begin : p_c1_feature_capture
        feature_q[0] <= feature0_i;
        feature_q[1] <= feature1_i;
        feature_q[2] <= feature2_i;
        feature_q[3] <= feature3_i;
    end

    // C2: seven parallel signed threshold comparators.
    always_ff @(posedge clk_i) begin : p_c2_parallel_compare
        compare_q[0] <= ($signed(feature_q[NODE0_FEATURE]) > $signed(NODE0_THRESHOLD));
        compare_q[1] <= ($signed(feature_q[NODE1_FEATURE]) > $signed(NODE1_THRESHOLD));
        compare_q[2] <= ($signed(feature_q[NODE2_FEATURE]) > $signed(NODE2_THRESHOLD));
        compare_q[3] <= ($signed(feature_q[NODE3_FEATURE]) > $signed(NODE3_THRESHOLD));
        compare_q[4] <= ($signed(feature_q[NODE4_FEATURE]) > $signed(NODE4_THRESHOLD));
        compare_q[5] <= ($signed(feature_q[NODE5_FEATURE]) > $signed(NODE5_THRESHOLD));
        compare_q[6] <= ($signed(feature_q[NODE6_FEATURE]) > $signed(NODE6_THRESHOLD));
    end

    // C3: eight independent 3-input leaf equations.
    always_ff @(posedge clk_i) begin : p_c3_onehot_leaf_decode
        leaf_q[0] <= (~compare_q[0]) & (~compare_q[1]) & (~compare_q[3]);
        leaf_q[1] <= (~compare_q[0]) & (~compare_q[1]) & ( compare_q[3]);
        leaf_q[2] <= (~compare_q[0]) & ( compare_q[1]) & (~compare_q[4]);
        leaf_q[3] <= (~compare_q[0]) & ( compare_q[1]) & ( compare_q[4]);
        leaf_q[4] <= ( compare_q[0]) & (~compare_q[2]) & (~compare_q[5]);
        leaf_q[5] <= ( compare_q[0]) & (~compare_q[2]) & ( compare_q[5]);
        leaf_q[6] <= ( compare_q[0]) & ( compare_q[2]) & (~compare_q[6]);
        leaf_q[7] <= ( compare_q[0]) & ( compare_q[2]) & ( compare_q[6]);
    end

    // C4: constant-folded one-hot action encoder.
    always_ff @(posedge clk_i) begin : p_c4_action_encode
        decision_o[0] <= |(leaf_q & BUY_MASK);
        decision_o[1] <= |(leaf_q & SELL_MASK);
    end

    // Four ownership FFs align source FDRE/Q at N with output FDRE/Q at N+4.
    always_ff @(posedge clk_i) begin : p_valid_pipeline
        if (rst_i) begin
            valid_c1_q       <= 1'b0;
            valid_c2_q       <= 1'b0;
            valid_c3_q       <= 1'b0;
            decision_valid_o <= 1'b0;
        end else begin
            valid_c1_q       <= feature_valid_i;
            valid_c2_q       <= valid_c1_q;
            valid_c3_q       <= valid_c2_q;
            decision_valid_o <= valid_c3_q;
        end
    end

endmodule

`default_nettype wire
