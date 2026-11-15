`timescale 1ns/1ps

module txtop_tb;

logic clk = 1'b0;
logic reset = 1'b1;
logic [7:0] wr_data = 8'h00;
logic wr_valid = 1'b0;
logic wr_last = 1'b0;
logic wr_ready;

logic [1:0] bits_out;
logic tx_enable;

integer frames_seen = 0;
integer byte_index = 0;
integer chunk_count = 0;
integer idle_clocks = 0;
logic [7:0] received_byte = 8'h00;
logic [7:0] expected_byte;
logic [31:0] expected_fcs;

txtop dut (
    .clk(clk),
    .reset(reset),
    .wr_data(wr_data),
    .wr_valid(wr_valid),
    .wr_last(wr_last),
    .wr_ready(wr_ready),
    .bits_out(bits_out),
    .tx_enable(tx_enable)
);

//50 mhz RMII clock
always #10 clk = ~clk;

//write one byte at a time and mark the last byte with wr_last
task automatic send_frame(input integer length, input logic [7:0] first_byte);
    for (integer i = 0; i < length; i = i + 1) begin
        @(negedge clk);
        wr_data = first_byte + i[7:0];
        wr_valid = 1'b1;
        wr_last = (i == length - 1);

        @(posedge clk);
        if (wr_ready !== 1'b1)
            $fatal(1, "tx buffer did not accept byte %0d", i);
    end

    @(negedge clk);
    wr_valid = 1'b0;
    wr_last = 1'b0;
endtask

//sample the pins like the PHY and put four chunks back into a byte
always @(posedge clk) begin
    if (!reset) begin
        if (tx_enable === 1'b1) begin
            if (frames_seen >= 2)
                $fatal(1, "Unexpected third frame");
            if (frames_seen == 1 && byte_index == 0 && chunk_count == 0 &&
                idle_clocks < 48)
                $fatal(1, "Only %0d idle clocks between frames", idle_clocks);

            received_byte = {bits_out, received_byte[7:2]};

            if (chunk_count == 3) begin
                if (byte_index < 7)
                    expected_byte = 8'h55;
                else if (byte_index == 7)
                    expected_byte = 8'hd5;
                else if (byte_index < 68) begin
                    //the first frame needs one zero before the FCS
                    if (frames_seen == 0 && byte_index == 67)
                        expected_byte = 8'h00;
                    else if (frames_seen == 0)
                        expected_byte = 8'h01 + (byte_index[7:0] - 8'd8);
                    else
                        expected_byte = 8'h41 + (byte_index[7:0] - 8'd8);
                end else begin
                    //expected crc values calculated with python zlib
                    if (frames_seen == 0)
                        expected_fcs = 32'h4dcf30b3;
                    else
                        expected_fcs = 32'h3c4cd6e0;

                    case (byte_index)
                        68: expected_byte = expected_fcs[7:0];
                        69: expected_byte = expected_fcs[15:8];
                        70: expected_byte = expected_fcs[23:16];
                        71: expected_byte = expected_fcs[31:24];
                        default: $fatal(1, "Extra byte in frame %0d", frames_seen + 1);
                    endcase
                end

                if (received_byte !== expected_byte)
                    $fatal(1, "Frame %0d byte %0d expected %02h got %02h",
                           frames_seen + 1, byte_index, expected_byte, received_byte);

                byte_index = byte_index + 1;
                chunk_count = 0;
            end else begin
                chunk_count = chunk_count + 1;
            end
        end else begin
            if (tx_enable !== 1'b0)
                $fatal(1, "tx_enable is unknown");

            //each frame is 8 preamble/sfd bytes, 60 body bytes and 4 fcs bytes
            if (byte_index != 0 || chunk_count != 0) begin
                if (byte_index != 72 || chunk_count != 0)
                    $fatal(1, "tx_enable dropped early in frame %0d", frames_seen + 1);

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

    //queue the second frame while the first one is still going out
    send_frame(59, 8'h01);
    send_frame(60, 8'h41);

    wait (frames_seen == 2);
    repeat (4) @(negedge clk);
    $display("PASS: both tx frames and the interframe gap are correct");
    $finish;
end

initial begin
    #20_000;
    $fatal(1, "timed out waiting for both tx frames");
end

endmodule
