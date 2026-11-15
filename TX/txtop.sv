module txtop (
    input logic clk,
    input logic reset, 

    //from frame source -> buffer
    input logic [7:0] wr_data,
    input logic wr_valid,
    input logic wr_last,
    output logic wr_ready,

    //from serializer to PHY
    output logic [1:0] bits_out,
    output logic tx_enable

);

//buffer and ctrl communications
logic tx_read_req;
logic fifo_q_valid; 
logic [8:0] fifo_q; 
logic frame_started;
logic frame_ready; 
//frame started is tx ctrl telling buffer that its taking a frame from the buffer
//frame ready is the buffer telling the tx ctrl that it has a frame ready for it

//ctrl and serializer communication
logic byte_ready;
logic tx_end; 
logic [7:0] tx_byte;
logic byte_valid;
logic byte_last; 

//ctrl and crc32 communication 
logic [31:0] fcsvalue;
logic crc_data_valid; 

//ctrl flags
logic have_word; 


txbuffer buffertop (
    .clk(clk),
    .reset(reset),
    .wr_data(wr_data), 
    .wr_valid(wr_valid),
    .wr_last(wr_last),
    .wr_ready(wr_ready),
    .tx_read_req(tx_read_req),
    .fifo_q(fifo_q),
    .fifo_q_valid(fifo_q_valid),
    .frame_started(frame_started),
    .frame_ready(frame_ready)
);

ctrl ctrltop (
    .clk(clk),
    .reset(reset),
    .start(frame_ready),
    .byte_ready(byte_ready),
    .tx_end(tx_end),
    .tx_byte(tx_byte),
    .byte_valid(byte_valid),
    .byte_last(byte_last),
    .fifo_q_valid(fifo_q_valid),
    .fifo_q(fifo_q),
    .tx_read_req(tx_read_req),
    .frame_started(frame_started), 
    .fcsvalue(fcsvalue),
    .crc_data_valid(crc_data_valid),
    .have_word(have_word) 
);

crc32 crc32top (
    .clk(clk),
    .reset(reset),
    .clear(frame_started), 
    .data_in(tx_byte),
    .data_valid(crc_data_valid),
    .crc_out(fcsvalue) 
);

rmii rmiitop (
    .clk(clk),
    .reset(reset), 
    .byte_valid(byte_valid),
    .byte_in(tx_byte),
    .byte_last(byte_last),
    .byte_ready(byte_ready),
    .tx_enable(tx_enable),
    .tx_end(tx_end),
    .bits_out(bits_out)
);

endmodule 