`timescale 1ps / 1ps
`default_nettype none

module tb_deterministic_tree_3stage_verify_top;

    localparam logic [1:0] HOLD = 2'b00;
    localparam logic [1:0] BUY  = 2'b01;
    localparam logic [1:0] SELL = 2'b10;

    logic clk_i       = 1'b0;
    logic rst_async_i = 1'b1;

    wire       sample_clk_o;
    wire       rst_sync_o;
    wire       source_valid_o;
    wire [3:0] source_index_o;
    wire       decision_valid_o;
    wire [1:0] decision_o;

    integer sample_cycle;
    integer checked;
    integer errors;
    integer launch_seen;
    integer k;

    logic       expected_valid  [0:63];
    logic [1:0] expected_action [0:63];
    logic [3:0] expected_index  [0:63];

    // 322.56 MHz: 3.1002 ns period.
    always #1550.1 clk_i = ~clk_i;

    deterministic_tree_3stage_verify_top dut (
        .clk_i             (clk_i),
        .rst_async_i       (rst_async_i),
        .sample_clk_o      (sample_clk_o),
        .rst_sync_o        (rst_sync_o),
        .source_valid_o    (source_valid_o),
        .source_index_o    (source_index_o),
        .decision_valid_o  (decision_valid_o),
        .decision_o        (decision_o)
    );

    function automatic logic [1:0] action_for_index(input logic [3:0] index);
        begin
            unique case (index)
                4'd0: action_for_index = HOLD;
                4'd1: action_for_index = SELL;
                4'd2: action_for_index = SELL;
                4'd3: action_for_index = HOLD;
                4'd4: action_for_index = HOLD;
                4'd5: action_for_index = BUY;
                4'd6: action_for_index = BUY;
                4'd7: action_for_index = HOLD;
                default: action_for_index = 2'b11;
            endcase
        end
    endfunction

    initial begin : p_test
        sample_cycle = 0;
        checked      = 0;
        errors       = 0;
        launch_seen  = 0;

        for (k = 0; k < 64; k = k + 1) begin
            expected_valid[k]  = 1'b0;
            expected_action[k] = HOLD;
            expected_index[k]  = 4'd0;
        end

        // Hold external reset long enough for GSR and the BUFG path to settle.
        repeat (6) @(negedge sample_clk_o);
        #200;
        rst_async_i = 1'b0;

        // Wait for the manual Triple-FF reset release.
        wait (rst_sync_o === 1'b0);

        while ((checked < 8) && (sample_cycle < 48)) begin
            @(negedge sample_clk_o);
            #200; // allow post-route OBUF skew to settle

            sample_cycle = sample_cycle + 1;

            // Check the output due on this sampled clock cycle.
            if (decision_valid_o !== expected_valid[sample_cycle]) begin
                $display("VALID ERROR cycle=%0d got=%b expected=%b",
                         sample_cycle,
                         decision_valid_o,
                         expected_valid[sample_cycle]);
                errors = errors + 1;
            end

            if (expected_valid[sample_cycle]) begin
                checked = checked + 1;

                if (decision_o !== expected_action[sample_cycle]) begin
                    $display("DATA ERROR cycle=%0d index=%0d got=%b expected=%b",
                             sample_cycle,
                             expected_index[sample_cycle],
                             decision_o,
                             expected_action[sample_cycle]);
                    errors = errors + 1;
                end
            end

            // Record the implemented source-Q event and schedule its result
            // exactly three sampled core-clock cycles later.
            if (source_valid_o === 1'b1) begin
                if (source_index_o !== launch_seen[3:0]) begin
                    $display("SOURCE ORDER ERROR cycle=%0d got_index=%0d expected_index=%0d",
                             sample_cycle,
                             source_index_o,
                             launch_seen);
                    errors = errors + 1;
                end

                expected_valid[sample_cycle + 3]  = 1'b1;
                expected_action[sample_cycle + 3] = action_for_index(source_index_o);
                expected_index[sample_cycle + 3]  = source_index_o;
                launch_seen = launch_seen + 1;
            end else if (source_valid_o !== 1'b0) begin
                $display("SOURCE VALID X/Z cycle=%0d value=%b",
                         sample_cycle,
                         source_valid_o);
                errors = errors + 1;
            end
        end

        // Ensure the valid pipeline drains and does not emit a ninth result.
        repeat (2) begin
            @(negedge sample_clk_o);
            #200;
            if (decision_valid_o !== 1'b0) begin
                $display("EXTRA OUTPUT ERROR decision_valid_o=%b", decision_valid_o);
                errors = errors + 1;
            end
        end

        if ((launch_seen == 8) && (checked == 8) && (errors == 0)) begin
            $display("");
            $display("PASS: 8/8 leaves matched the exact three-cycle source-Q contract");
            $display("Latency = 3 cycles x 3.1002 ns = 9.3006 ns");
            $display("");
            $finish;
        end else begin
            $fatal(1,
                   "FAIL: launches=%0d checked=%0d errors=%0d",
                   launch_seen,
                   checked,
                   errors);
        end
    end

    initial begin : p_timeout
        #500000;
        $fatal(1,
               "TIMEOUT: launches=%0d checked=%0d errors=%0d",
               launch_seen,
               checked,
               errors);
    end

endmodule

`default_nettype wire
