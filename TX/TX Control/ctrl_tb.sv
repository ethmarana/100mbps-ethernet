`timescale 1ns/1ps

module ctrl_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic start = 1'b0;

    //separation of ports is defined in ctrl.sv
    logic byte_ready = 1'b0;
    logic [7:0] tx_byte;
    logic byte_valid;

    logic fifo_q_valid = 1'b0;
    logic [8:0] fifo_q = '0;
    logic tx_read_req;
    logic frame_started;
    logic have_word;

    logic [31:0] crc_state = '1;
    wire [31:0] fcsvalue = ~crc_state;
    logic crc_data_valid;

    int frame_length = 0;
    int fifo_index = 0;
    int ready_cycle = 0;

    ctrl dut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .byte_ready(byte_ready),
        .tx_byte(tx_byte),
        .byte_valid(byte_valid),
        .fifo_q_valid(fifo_q_valid),
        .fifo_q(fifo_q),
        .tx_read_req(tx_read_req),
        .frame_started(frame_started),
        .fcsvalue(fcsvalue),
        .crc_data_valid(crc_data_valid),
        .have_word(have_word)
    );

    always #10 clk = ~clk;

    //RMII serializer accepts one byte every four clocks
    //simulating a RMII serializer here 
    always @(negedge clk) begin
        byte_ready = (ready_cycle % 4 == 0);
        ready_cycle = ready_cycle + 1;
    end

    //generates test bytes for the tests 
    function automatic logic [7:0] frame_byte(input int index);
        return 8'h80 ^ index[7:0];
    endfunction

    //acts like the fifo for this test, returning the bytes that are requested from ctrl
    always @(posedge clk) begin
        if (reset) begin
            fifo_index <= 0;
            fifo_q <= '0;
            fifo_q_valid <= 1'b0;
        end else begin
            fifo_q_valid <= tx_read_req;
            if (frame_started)
                fifo_index <= 0;
            if (tx_read_req) begin
                if (fifo_index >= frame_length)
                    $fatal(1, "Read past the end of the %0d-byte frame", frame_length);
                fifo_q <= {(fifo_index == frame_length - 1), frame_byte(fifo_index)};
                fifo_index <= fifo_index + 1;
            end
        end
    end

    // stand in for crc32.sv
    // calculations are against Python zlib
    function automatic logic [31:0] crc_next(
        input logic [31:0] previous,
        input logic [7:0] data
    );
        logic [31:0] value;
        value = previous ^ {24'b0, data};
        for (int bit_index = 0; bit_index < 8; bit_index++) begin
            if (value[0])
                value = (value >> 1) ^ 32'hEDB88320;
            else
                value = value >> 1;
        end
        return value;
    endfunction

    //register for the stand-in crc 

    always @(posedge clk) begin
        if (reset || frame_started)
            crc_state <= '1;
        else if (crc_data_valid)
            crc_state <= crc_next(crc_state, tx_byte);
    end

    //ensures that all signals are 0 when in idle 
    task automatic check_idle;
        if ({byte_valid, tx_read_req, frame_started, crc_data_valid, have_word}
                !== 5'b0)
            $fatal(1, "Unexpected output while idle");

    endtask

    // generates predictable test bytes and vary the input length to test padding.
    // check that the four transmitted FCS bytes match the expected FCS
    // calculated from the input bytes and any required zero padding.
    task automatic check_frame(input int length, input logic [31:0] expected_fcs);
        int body_length;
        int sent;
        int fcs_index;
        logic [7:0] expected_byte;
        logic expected_crc_enable;
        logic stalled;
        logic [7:0] stalled_byte;

        body_length = (length < 60) ? 60 : length;
        sent = 0;
        stalled = 1'b0;

        @(negedge clk);
        frame_length = length;
        start = 1'b1;
        @(posedge clk);
        if (frame_started !== 1'b1)
            $fatal(1, "Controller did not claim the %0d-byte frame", length);
        @(negedge clk);
        start = 1'b0;

        // sample each handshake at the rising edge, before state changes.
        while (sent < 8 + body_length + 4) begin
            @(posedge clk);

            if (frame_started !== 1'b0)
                $fatal(1, "Unexpected second frame claim");
            if (stalled && (byte_valid !== 1'b1 || tx_byte !== stalled_byte))
                $fatal(1, "Output changed while stalled at byte %0d", sent);

            expected_crc_enable = byte_valid && byte_ready &&
                                  (sent >= 8) && (sent < 8 + body_length);
            if (crc_data_valid !== expected_crc_enable)
                $fatal(1, "Wrong CRC enable at byte %0d of %0d-byte input",
                       sent, length);

            stalled = byte_valid && !byte_ready;
            stalled_byte = tx_byte;

            if (byte_valid && byte_ready) begin
                if (sent < 7)
                    expected_byte = 8'h55;
                else if (sent == 7)
                    expected_byte = 8'hD5;
                else if (sent < 8 + length)
                    expected_byte = frame_byte(sent - 8);
                else if (sent < 8 + body_length)
                    expected_byte = 8'h00;
                else begin
                    fcs_index = sent - 8 - body_length;
                    expected_byte = expected_fcs[fcs_index * 8 +: 8];
                end

                if (tx_byte !== expected_byte)
                    $fatal(1, "Input length %0d, TX byte %0d: expected %02h, got %02h",
                           length, sent, expected_byte, tx_byte);
                sent++;
            end
        end

        repeat (4) begin
            @(posedge clk);
            check_idle();
        end
        if (fifo_index != length)
            $fatal(1, "Expected %0d FIFO reads, got %0d", length, fifo_index);
        $display("PASS: %0d input bytes, %0d pad bytes, FCS %08h",
                 length, body_length - length, expected_fcs);
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 1'b0;
        @(posedge clk);
        check_idle();

        // no reset inbetween frames so the controller is forced to reinitialize its counts 
        check_frame(58, 32'h4FAC6670);
        check_frame(59, 32'h51862042);
        check_frame(60, 32'h0D354A46);
        check_frame(65, 32'h7FE06B14);

        $display("PASS: all TX controller tests");
        $finish;
    end

 
endmodule
