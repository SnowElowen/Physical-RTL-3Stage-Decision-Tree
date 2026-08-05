`timescale 1ps / 1ps
`default_nettype none

// ============================================================================
// Implemented source-FDRE wrapper for deterministic_tree_4stage.
//
// The eight test vectors are launched by real fabric registers inside the
// implemented netlist.  The measured latency contract is therefore:
//
//   source_valid_o/source_index_o Q at cycle N
//       -> decision_valid_o/decision_o Q at cycle N+4.
//
// The testbench drives only clk_i and rst_async_i; it never changes feature
// inputs on a DUT clock edge.
// ============================================================================
module deterministic_tree_4stage_verify_top (
    input  wire        clk_i,
    input  wire        rst_async_i,

    output wire        sample_clk_o,
    output wire        rst_sync_o,
    output logic       source_valid_o,
    output logic [3:0] source_index_o,
    output wire        decision_valid_o,
    output wire [1:0]  decision_o
);

    localparam logic [1:0] HOLD = 2'b00;
    localparam logic [1:0] BUY  = 2'b01;
    localparam logic [1:0] SELL = 2'b10;

    // ------------------------------------------------------------------------
    // Clock ownership: one explicit BUFG owns every implemented register.
    // sample_clk_o is only an observation copy for the testbench.
    // ------------------------------------------------------------------------
    wire core_clk;

    BUFG u_core_clk_bufg (
        .I (clk_i),
        .O (core_clk)
    );

    assign sample_clk_o = core_clk;

    // ------------------------------------------------------------------------
    // Manual Triple-FF asynchronous-reset release synchronizer.
    // Asynchronous assertion, three core_clk edges for deterministic release.
    // ------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic rst_meta_q;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic rst_sync2_q;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic rst_sync3_q;

    always_ff @(posedge core_clk or posedge rst_async_i) begin
        if (rst_async_i) begin
            rst_meta_q  <= 1'b1;
            rst_sync2_q <= 1'b1;
            rst_sync3_q <= 1'b1;
        end else begin
            rst_meta_q  <= 1'b0;
            rst_sync2_q <= rst_meta_q;
            rst_sync3_q <= rst_sync2_q;
        end
    end

    assign rst_sync_o = rst_sync3_q;

    // ------------------------------------------------------------------------
    // Compile-time fixed vector ROM feeding real source FDREs.
    // This logic is upstream of the measured source-Q boundary.
    // ------------------------------------------------------------------------
    logic [3:0] launch_index_q;

    logic               launch_valid_d;
    logic signed [15:0] launch_f0_d;
    logic signed [15:0] launch_f1_d;
    logic signed [15:0] launch_f2_d;
    logic signed [15:0] launch_f3_d;

    always_comb begin
        launch_valid_d = 1'b1;
        launch_f0_d    = 16'sd0;
        launch_f1_d    = 16'sd0;
        launch_f2_d    = 16'sd0;
        launch_f3_d    = 16'sd0;

        unique case (launch_index_q)
            4'd0: begin // leaf 0 -> HOLD
                launch_f0_d =  16'sd0;
                launch_f1_d = -16'sd30;
                launch_f2_d =  16'sd0;
                launch_f3_d =  16'sd0;
            end
            4'd1: begin // leaf 1 -> SELL
                launch_f0_d =  16'sd0;
                launch_f1_d = -16'sd30;
                launch_f2_d =  16'sd10;
                launch_f3_d =  16'sd0;
            end
            4'd2: begin // leaf 2 -> SELL
                launch_f0_d = 16'sd0;
                launch_f1_d = 16'sd0;
                launch_f2_d = 16'sd10;
                launch_f3_d = 16'sd0;
            end
            4'd3: begin // leaf 3 -> HOLD
                launch_f0_d = 16'sd0;
                launch_f1_d = 16'sd0;
                launch_f2_d = 16'sd20;
                launch_f3_d = 16'sd0;
            end
            4'd4: begin // leaf 4 -> HOLD
                launch_f0_d =  16'sd200;
                launch_f1_d =  16'sd0;
                launch_f2_d =  16'sd0;
                launch_f3_d = -16'sd10;
            end
            4'd5: begin // leaf 5 -> BUY
                launch_f0_d = 16'sd200;
                launch_f1_d = 16'sd0;
                launch_f2_d = 16'sd0;
                launch_f3_d = 16'sd0;
            end
            4'd6: begin // leaf 6 -> BUY
                launch_f0_d = 16'sd200;
                launch_f1_d = 16'sd40;
                launch_f2_d = 16'sd0;
                launch_f3_d = 16'sd20;
            end
            4'd7: begin // leaf 7 -> HOLD
                launch_f0_d = 16'sd200;
                launch_f1_d = 16'sd40;
                launch_f2_d = 16'sd0;
                launch_f3_d = 16'sd30;
            end
            default: begin
                launch_valid_d = 1'b0;
            end
        endcase
    end

    // Real implemented source Q boundary.
    (* KEEP = "TRUE" *) logic signed [15:0] source_f0_q;
    (* KEEP = "TRUE" *) logic signed [15:0] source_f1_q;
    (* KEEP = "TRUE" *) logic signed [15:0] source_f2_q;
    (* KEEP = "TRUE" *) logic signed [15:0] source_f3_q;

    always_ff @(posedge core_clk) begin
        if (rst_sync3_q) begin
            launch_index_q <= 4'd0;
            source_valid_o <= 1'b0;
            source_index_o <= 4'd0;
            source_f0_q    <= 16'sd0;
            source_f1_q    <= 16'sd0;
            source_f2_q    <= 16'sd0;
            source_f3_q    <= 16'sd0;
        end else begin
            source_valid_o <= launch_valid_d;
            source_index_o <= launch_index_q;
            source_f0_q    <= launch_f0_d;
            source_f1_q    <= launch_f1_d;
            source_f2_q    <= launch_f2_d;
            source_f3_q    <= launch_f3_d;

            if (launch_index_q < 4'd8) begin
                launch_index_q <= launch_index_q + 4'd1;
            end
        end
    end

    deterministic_tree_4stage u_core (
        .clk_i            (core_clk),
        .rst_i            (rst_sync3_q),
        .feature_valid_i  (source_valid_o),
        .feature0_i       (source_f0_q),
        .feature1_i       (source_f1_q),
        .feature2_i       (source_f2_q),
        .feature3_i       (source_f3_q),
        .decision_valid_o (decision_valid_o),
        .decision_o       (decision_o)
    );

endmodule

`default_nettype wire
