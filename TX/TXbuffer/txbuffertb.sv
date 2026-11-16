module txbuffertb;

logic clk;
logic reset;

// write from frame source
logic [7:0] wr_data;
logic wr_valid;
logic wr_last;
logic wr_ready;

// read -> tx ctrl
logic tx_read_req;
logic [8:0] fifo_q;
logic fifo_q_valid;
    
// frame control -> tx ctrl
logic       frame_started;
logic       frame_ready;

txbuffer dut (
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

always #10 clk = ~clk; 

initial begin
    clk = 1'b0; 
    reset = 1'b1;
    wr_data = 1'b0;
    wr_valid = 1'b0;
    wr_last = 1'b0; 
    tx_read_req = 1'b0;
    frame_started = 1'b0;
    @(negedge clk);
    @(negedge clk);
    reset = 1'b0;
    if (frame_ready !== 1'b0) begin
        $fatal(1, "ERROR, no frames loaded but frame ready signal");
    end 
    if (fifo_q_valid !== 1'b0) begin
        $fatal(1, "ERROR, no frames loaded / requested but fifo_q_valid high");
    end 

    //send A1, B2, C3 for later read requests
    //storing it into the fifo 
    @(negedge clk); 
    wr_valid = 1'b1;
    wr_data = 8'hA1;
    @(negedge clk);
    if (frame_ready !== 1'b0)
        $fatal(1, "frame_ready went high after writing A1");
    wr_data = 8'hB2;
    @(negedge clk);
    if (frame_ready !== 1'b0)
        $fatal(1, "frame_ready went high after writing B2");
    wr_data = 8'hC3;
    wr_last = 1'b1;
    @(negedge clk); 
    wr_last = 1'b0;
    wr_valid = 1'b0;
    if (frame_ready !== 1'b1) begin
        $fatal(1, "Frame Ready Logic Error, read side");
    end 
    @(negedge clk);
    frame_started = 1'b1; 
    @(negedge clk); 
    frame_started = 1'b0;
    @(negedge clk); 
    if (frame_ready !== 1'b0) begin
        $fatal(1, "Frame Ready Logic Error, write side");
    end 


    //start read request check, sending the payload of
    //A1, B2, C3

    //A1
    @(negedge clk); 
    tx_read_req = 1'b1;
    @(negedge clk); 
    if (fifo_q_valid !== 1'b1) begin
        $fatal(1, "read validation not working");
    end 
    if (frame_ready !== 1'b0) begin
        $fatal(1, "Frame Ready Logic Error, write side");
    end 
    if (fifo_q !== 9'h0A1) begin
        $fatal(1, "read ERROR, expected 0A1, recieved %08h", fifo_q);
    end

    //B2
    @(negedge clk); 
    if (fifo_q_valid !== 1'b1) begin
        $fatal(1, "read validation not working");
    end 
    if (fifo_q !== 9'h0B2) begin
        $fatal(1, "read ERROR, expected 0B2, recieved %08h", fifo_q);
    end
    if (frame_ready !== 1'b0) begin
        $fatal(1, "Frame Ready Logic Error, write side");
    end 

    //C3
    @(negedge clk); 
    if (fifo_q_valid !== 1'b1) begin
        $fatal(1, "read validation not working");
    end 
    if (fifo_q !== 9'h1C3) begin
        $fatal(1, "read ERROR, expected 1C3, recieved %08h", fifo_q);
    end

    //If all frames are read, the fifo is empty, so fifo_q_valid should be 0
    @(negedge clk);
    if (fifo_q_valid !== 1'b0) begin
        $fatal(1, "fifo_q_valid logic error");
    end 
    tx_read_req = 1'b0; 
    $finish; 
end 

endmodule 