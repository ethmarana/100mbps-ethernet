module txtop (
    input logic clk,
    input logic reset, 

    //from frame source -> buffer
    input logic [7:0] wr_data,
    input logic wr_valid,
    input logic wr_last,
    input logic wr_ready,


);

txbuffer topinstance (
    .clk(clk),
    .reset(reset),
    .wr_data(wr_data), 
    .wr_valid(wr_valid),
    .wr_last(wr_last),
    .wr_ready(wr_ready),

);


endmodule 

module txbuffer (
    input  logic clk,
    input  logic reset,

    // write from frame source
    input  logic [7:0] wr_data,
    input  logic wr_valid,
    input  logic wr_last,
    output logic wr_ready,

    // read -> tx ctrl
    input  logic tx_read_req,
    output logic [8:0] fifo_q,
    output logic fifo_q_valid,
    //fifo_q valid means that the requested byte from tx ctrl is ready
    

    // frame control -> tx ctrl
    input  logic       frame_started,
    output logic       frame_ready
    //frame started is tx ctrl telling buffer that its taking a frame from the buffer
    //frame ready is the buffer telling the tx ctrl that it has a frame ready for it
);