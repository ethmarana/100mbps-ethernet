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

//wr valid means the frame source is offering a byte
//wr ready means the buffer is ready to take the byte 

logic fifo_full, fifo_write, fifo_empty;
logic [12:0] frame_counter; 

assign fifo_write = wr_valid && wr_ready; 
assign wr_ready = ~fifo_full && ~reset;

//syncfifo buffer

//1 extra bit as a flag for the last byte in a frame
//can hold two 2 KB frames at once hence 2 * 2048 = 4096
//basically, if wr_last is high, that means that the last byte of
// the ethernet payload for that frame has been sent

//ethernet frame is 64 bytes, although 46 is the minimum for payload
// + padding 
// the buffer takes in the ethernet payload, then the rest of the
// MAC adds the preamble + delimiter + 4 bytes of fcs + padding 
syncfifo #(.data(9), .regamt(4096)) buffer (
    .clk(clk),
    .reset(reset),
    .datain({wr_last, wr_data}),
    .write(fifo_write),
    .full(fifo_full),
    .readvalue(fifo_q),
    .empty(fifo_empty),
    .read(tx_read_req)
);

//frame counter 
//when a frame is loaded, frame_counter +1
//when a frame is read, frame_counter -1

always_ff @(posedge clk) begin
    if (reset) begin
        frame_counter <= 13'b0;
        fifo_q_valid  <= 1'b0;
    end else begin
        fifo_q_valid <= tx_read_req && ~fifo_empty;

        if (fifo_write && wr_last && !frame_started) begin
            frame_counter <= frame_counter + 13'd1;
        end else if (frame_started && !(fifo_write && wr_last)) begin
            frame_counter <= frame_counter - 13'd1;
        end
    end
end

always_comb begin
    frame_ready = frame_counter != 13'd0;
end 

endmodule 

