`timescale 1ns/1ps

module rmii_tb;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic byte_valid = 1'b0;
    logic [7:0] byte_in = 8'h00;
    logic byte_last = 1'b0;

    logic byte_ready;
    logic tx_enable;
    logic tx_end;
    logic [1:0] bits_out;

    rmii dut (
        .clk(clk),
        .reset(reset),
        .byte_valid(byte_valid),
        .byte_in(byte_in),
        .byte_last(byte_last),
        .byte_ready(byte_ready),
        .tx_enable(tx_enable),
        .tx_end(tx_end),
        .bits_out(bits_out)
    );

    //50 MHz clock
    always #10 clk = ~clk; 

    task automatic check_chunk(input logic [1:0] expected_bits,
                               input logic expected_ready);
        // reads the same values that PHY samples 
        @(posedge clk);
        if (tx_enable !== 1'b1 || tx_end !== 1'b0 ||
            bits_out !== expected_bits || byte_ready !== expected_ready)
            $fatal(1, "At %0t expected bits=%b ready=%b, got bits=%b ready=%b enable=%b end=%b",
                   $time, expected_bits, expected_ready, bits_out, byte_ready,
                   tx_enable, tx_end);
    endtask

    initial begin
        repeat (2) @(negedge clk);
        if ({byte_ready, tx_enable, tx_end, bits_out} !== 5'b0)
            $fatal(1, "Expected idle outputs during reset");

        reset = 1'b0;
        byte_valid = 1'b1;
        byte_in = 8'hD5;

        @(posedge clk);
        if (byte_ready !== 1'b1)
            $fatal(1, "Serializer did not accept the first byte while idle");

        // offers A1 while D1 is still going out 
        @(negedge clk);
        byte_in = 8'hA1;
        byte_last = 1'b1;
        // D5, bits [1:0]
        check_chunk(2'b01, 1'b0); 
        check_chunk(2'b01, 1'b0);
        check_chunk(2'b01, 1'b0);
        check_chunk(2'b11, 1'b1);   
        // D5 finishes and A1 loads here
        @(negedge clk);
        byte_valid = 1'b0;
        byte_last = 1'b0;

        // A1, bits [1:0]
        check_chunk(2'b01, 1'b0); 
        check_chunk(2'b00, 1'b0);
        check_chunk(2'b10, 1'b0);
        check_chunk(2'b10, 1'b0); 
        // Last chunk of the marked byte

        // after the clocked updates, TX is idle and tx_end is high.
        #1;
        if (tx_enable !== 1'b0 || tx_end !== 1'b1 || bits_out !== 2'b00)
            $fatal(1, "Expected idle pins and a tx_end pulse after the last chunk");

        @(negedge clk);
        if (tx_end !== 1'b1)
            $fatal(1, "tx_end cleared before the next clock");

        @(posedge clk);
        #1;
        if ({tx_enable, tx_end} !== 2'b00)
            $fatal(1, "tx_end should clear after one clock");

        $display("PASS: RMII serializer");
        $finish;
    end
endmodule
