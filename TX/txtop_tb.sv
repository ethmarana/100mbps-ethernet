`timescale 1ns/1ps

module txtop_tb;

localparam int CUT_THROUGH = 0;  // change to 1 for the cut-through run
localparam int FRAME_BYTES = 1514;  // 14 header bytes + 1500 payload bytes
localparam int FCS_START = 8 + FRAME_BYTES;
localparam int TX_BYTES = FCS_START + 4;

logic clk = 1'b0;
logic reset = 1'b1;
logic [7:0] wr_data = 8'h00;
logic wr_valid = 1'b0;
logic wr_last = 1'b0;
logic wr_ready;

logic [1:0] bits_out;
logic tx_enable;

integer cycle = 0;
integer first_write = -1;
integer last_write = -1;
integer first_tx = -1;
integer second_tx = -1;
integer latency_clocks;
integer frame_interval_ns;

integer frames_seen = 0;
integer byte_index = 0;
integer chunk_count = 0;
integer idle_clocks = 0;
logic [7:0] received_byte = 8'h00;
logic [7:0] expected_byte;
logic [31:0] expected_fcs;

txtop #(
    .CUT_THROUGH(CUT_THROUGH),
    .START_THRESHOLD(1)
) dut (
    .clk(clk),
    .reset(reset),
    .wr_data(wr_data),
    .wr_valid(wr_valid),
    .wr_last(wr_last),
    .wr_ready(wr_ready),
    .bits_out(bits_out),
    .tx_enable(tx_enable)
);

// 50 mhz rmii clock
always #10 clk = ~clk;

// send one byte every four clocks
task automatic send_frame(input logic [7:0] first_byte);
    for (integer i = 0; i < FRAME_BYTES; i = i + 1) begin
        @(negedge clk);
        wr_data = first_byte + i[7:0];
        wr_valid = 1'b1;
        wr_last = (i == FRAME_BYTES - 1);

        @(posedge clk);
        if (wr_ready !== 1'b1)
            $fatal(1, "tx buffer did not accept byte %0d", i);

        @(negedge clk);
        wr_valid = 1'b0;
        wr_last = 1'b0;
        repeat (2) @(negedge clk);
    end
endtask

// record the input and output edges and check what the phy sees
always @(posedge clk) begin
    if (!reset) begin
        cycle = cycle + 1;

        if (wr_valid && wr_ready) begin
            if (first_write == -1)
                first_write = cycle;
            if (wr_last && last_write == -1)
                last_write = cycle;
        end

        if (tx_enable === 1'b1) begin
            if (frames_seen >= 2)
                $fatal(1, "unexpected third frame");

            if (byte_index == 0 && chunk_count == 0) begin
                if (frames_seen == 0) begin
                    first_tx = cycle;
                end else begin
                    second_tx = cycle;
                    if (idle_clocks < 48)
                        $fatal(1, "only %0d idle clocks between frames",
                               idle_clocks);
                end
            end

            // put four 2-bit chunks back into a byte
            received_byte = {bits_out, received_byte[7:2]};

            if (chunk_count == 3) begin
                if (byte_index < 7) begin
                    expected_byte = 8'h55;
                end else if (byte_index == 7) begin
                    expected_byte = 8'hd5;
                end else if (byte_index < FCS_START) begin
                    if (frames_seen == 0)
                        expected_byte = 8'h02 + (byte_index[7:0] - 8'd8);
                    else
                        expected_byte = 8'h42 + (byte_index[7:0] - 8'd8);
                end else begin
                    // expected crc for each input pattern
                    if (frames_seen == 0)
                        expected_fcs = 32'h611bd196;
                    else
                        expected_fcs = 32'hd9aabbae;

                    case (byte_index - FCS_START)
                        0: expected_byte = expected_fcs[7:0];
                        1: expected_byte = expected_fcs[15:8];
                        2: expected_byte = expected_fcs[23:16];
                        3: expected_byte = expected_fcs[31:24];
                        default: $fatal(1, "extra byte in frame %0d",
                                        frames_seen + 1);
                    endcase
                end

                if (received_byte !== expected_byte)
                    $fatal(1, "frame %0d byte %0d expected %02h got %02h",
                           frames_seen + 1, byte_index,
                           expected_byte, received_byte);

                byte_index = byte_index + 1;
                chunk_count = 0;
            end else begin
                chunk_count = chunk_count + 1;
            end
        end else begin
            if (tx_enable !== 1'b0)
                $fatal(1, "tx_enable is unknown");

            // tx_enable should stay high until the whole frame goes out
            if (byte_index != 0 || chunk_count != 0) begin
                if (byte_index != TX_BYTES || chunk_count != 0)
                    $fatal(1, "tx_enable dropped early in frame %0d",
                           frames_seen + 1);

                frames_seen = frames_seen + 1;
                byte_index = 0;
            end

            if (frames_seen == 1)
                idle_clocks = idle_clocks + 1;
        end
    end
end

initial begin
    repeat (2) @(negedge clk);
    reset = 1'b0;

    send_frame(8'h02);
    send_frame(8'h42);

    wait (frames_seen == 2);
    @(negedge clk);

    if (CUT_THROUGH && first_tx >= last_write)
        $fatal(1, "cut-through did not start before the final write");
    if (!CUT_THROUGH && first_tx <= last_write)
        $fatal(1, "store-and-forward started too early");

    latency_clocks = first_tx - first_write;
    frame_interval_ns = (second_tx - first_tx) * 20;

    $display("cut_through = %0d", CUT_THROUGH);
    $display("tx start latency = %0d clocks, %0d ns",
             latency_clocks, latency_clocks * 20);
    $display("idle clocks between frames = %0d", idle_clocks);
    $display("payload throughput = %0.2f mb/s", 12_000_000.0 / frame_interval_ns);
    $display("pass: both frames, fcs values, and interframe gap");
    $finish;
end

initial begin
    #500_000;
    $fatal(1, "timed out waiting for both tx frames");
end

endmodule