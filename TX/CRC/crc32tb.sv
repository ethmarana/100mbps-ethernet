`timescale 1ns / 1ps

module crc32tb;
    logic reset, clear, data_valid;
    logic [7:0] data_in;
    logic [31:0] crc_out;

    crc32 instance1 (
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .data_valid(data_valid),
        .data_in(data_in),
        .crc_out(crc_out)
    );

    // match 125 mhz GMII clock
    always #4 clk = ~clk;

    initial begin
    logic clk = 1'b0;
        reset = 1'b1;
        clear = 1'b0;
        data_valid = 1'b0;
        data_in = 8'h00;

        @(negedge clk);
        reset = 1'b0;
        data_valid = 1'b1;
        data_in = 8'h41; // ASCII A

        @(negedge clk);
        data_in = 8'h42; // ASCII B

        @(negedge clk);
        data_valid = 1'b0;

        if (crc_out !== 32'h30694C07)
            $fatal(1, "Expected CRC 30694C07, got %08h.", crc_out);

        $display("PASS. CRC of AB is %08h.", crc_out);
        $finish;
    end
endmodule
