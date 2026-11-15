module rmii (
    //the rmii takes in bytes from ctrl, and turns them into
    //timed signals so they are are in sync with the PHY
    //the byte is cut down into 2 bit chunks to send to the 
    //PHY

    input logic clk,
    input logic reset,

    //TX Ctrl communication 
    input logic byte_valid, 
    input logic [7:0] byte_in,
    //signal from ctrl.sv that tells if the byte it is working on
    //is the last byte 
    input logic byte_last, 
    output logic byte_ready,
    output logic tx_enable,
    output logic tx_end,


    //PHY communication 
    output logic [1:0] bits_out

);

//flag to know if the serializer is currently working on a byte 
logic busy; 

//inteernal register to hold byte_last 
logic working_last; 

//count of which part of the byte_in it is outputting to the PHY
logic [1:0] byte_count;

//working byte register
logic [7:0] working_byte; 

always_ff @(posedge clk) begin
    if (reset) begin
        byte_count <= 2'b0; 
        working_byte <= 8'b0; 
        busy <= 1'b0;
        working_last <= 1'b0; 
        tx_end <= 1'b0; 
    end else begin
        tx_end <= 1'b0; 
        //on a successful handshake, load the byte from ctrl.sv into the working
        //byte register, and turn on the busy flag 
        //if the ctrl pulses byte_last, it also keeps that as well 
        if (byte_valid && byte_ready) begin
            byte_count <= 2'b0; 
            busy <= 1'b1;
            working_last <= byte_last; 
            working_byte <= byte_in; 
        //increment serializer
        end else if (byte_count < 2'd3 && busy) begin
            byte_count <= byte_count + 2'd1;
        //at 3, the last section is finished and the byte is fully loaded
        //serializer is ready for the next byte 
        end else if (byte_count == 2'd3 && busy) begin
            busy <= 1'b0;
            tx_end <= working_last; 
        end  
        
    end 

end 

always_comb begin
    byte_ready = 1'b0;
    bits_out = 2'b0; 
    tx_enable = busy; 
    if (busy) begin
        case (byte_count) 
            2'd0: bits_out = working_byte[1:0];
            2'd1: bits_out = working_byte[3:2];
            2'd2: begin 
                bits_out = working_byte[5:4];
            end 
            2'd3: begin
                bits_out = working_byte[7:6];
                byte_ready = !working_last;
            end 
        endcase
    end else begin
        byte_ready = 1'b1; 
    end 
    if (reset) begin
        byte_ready = 1'b0; 
    end 
    
end 



endmodule 