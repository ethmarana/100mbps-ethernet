module ctrl (
    input logic clk,
    input logic reset,
    input logic start,

    //RMII serializer communication 
    input logic byte_ready, 
    //byte_ready is the serializer saying its ready to take in a byte
    output logic [7:0] tx_byte,
    output logic byte_valid, 

    //Buffer communication 
    input logic fifo_q_valid,
    input logic [8:0] fifo_q,
    output logic tx_read_req,
    output logic frame_started,

    //CRC32 communication
    input logic [31:0] fcsvalue,
    output logic crc_data_valid,
    //crc_data_valid tells the CRC that it can take the byte on tx_byte
    //and perform the CRC32 calculations on it

    //Flags
    output logic have_word
    
);


//preamble counter register 
logic [2:0] preamble_count; 
//FCS counter register
logic [1:0] fcs_count; 
//PAD counter register
logic [5:0] frame_byte_count;

//FSM states
//Control the construction of a packet, adding the preamble, SFD, payload from the sources, and FCS all together 
//to be pushed out to the PHY through the RMII serializer 
typedef enum {
    IDLE,
    PREAMBLE, 
    SFD,
    FRAME,
    FCS,
    PAD

} states; 

states cstate, nstate; 

always_ff @(posedge clk) begin
    if (reset) begin
        cstate <= IDLE;
        preamble_count <= 3'b0; 
        have_word <= 1'b0;
        fcs_count <= 2'b0;
        frame_byte_count <= 6'b0;
    end else begin
        cstate <= nstate; 
        if (cstate == IDLE) begin
            preamble_count <= 3'b0; 
            fcs_count <= 2'b0;
            frame_byte_count <= 6'b0;
        end else if ((cstate == PREAMBLE && byte_ready) && preamble_count < 6) begin
            //on every 8'h55 sent for the ethernet preamble, preamble_count 
            //increases by 1 since 7 8'h55s are needed for the
            //preamble of an ethernet packet and when preamble_count == 6
            //the seventh 8'h55 is offered 
            preamble_count <= preamble_count + 1; 
        end 
        if (cstate == FRAME && fifo_q_valid) begin
            have_word <= 1'b1;
        end else if (cstate == FRAME && byte_ready && byte_valid) begin
            have_word <= 1'b0; 
        end 
        if (cstate == FCS && byte_ready && fcs_count < 2'd3) begin
            fcs_count <= fcs_count + 2'd1;
        end 
        if (crc_data_valid && frame_byte_count < 6'd60) begin
            frame_byte_count <= frame_byte_count + 6'd1;
        end
        

    end 
end 

always_comb begin
    nstate = cstate;
    tx_read_req = 1'b0; 
    tx_byte = 8'b0; 
    byte_valid = 1'b0;
    frame_started = 1'b0;
    crc_data_valid = 1'b0;
    if (start && (cstate == IDLE)) begin
        nstate = PREAMBLE; 
        frame_started = 1'b1;
    end
    if (cstate == PREAMBLE) begin
        tx_byte = 8'h55;
        byte_valid = 1'b1;
        if (preamble_count == 3'd6 && byte_ready) begin
            nstate = SFD;
        end 
    end 
    //byte_ready pulses the request of the new word 
    if (cstate == SFD) begin
        tx_byte = 8'hD5;
        byte_valid = 1'b1;
        if (byte_ready) begin
            nstate = FRAME;
            tx_read_req = 1'b1; 
        end 
    end 
    if (cstate == FRAME) begin
    //when recieving frames from the source, the frames are
    //simultaneously sent to the CRC32 for FCS calculation,
    //hence the crc_data_valid pulse which connects to the
    //data_valid input port of crc32.sv
        tx_byte = fifo_q[7:0]; 
        byte_valid = have_word; 
        if (have_word && byte_ready) begin
            crc_data_valid = 1'b1; 
            if (fifo_q[8] == 1'b1) begin
    //ethernet frame needs a byte count of at least 60 for the header + payload
    //14 bytes of header, 46 bytes of payload
    //if the count is smaller than 60, padding needs to be added to the payload
    //to reach this minimum 
                if (frame_byte_count < 6'd59) begin
                    nstate = PAD;
                end else begin
                    //if the minimum is already met, the FSM can skip PAD
                    //and go straight to FCS 
                    nstate = FCS;
                end
            end else begin
                tx_read_req = 1'b1;
            end 
        end 
    end 
    if (cstate == FCS) begin
        //fcs gets fed to the RMII serializer one byte at a time
        //fcs_count keeps the count of the specific byte of the FCS it is 
        //feeding to the RMII serializer 
        byte_valid = 1'b1; 
        case (fcs_count)
        2'd0: tx_byte = fcsvalue[7:0];

        2'd1: tx_byte = fcsvalue[15:8]; 

        2'd2: tx_byte = fcsvalue[23:16];

        2'd3: begin
            tx_byte = fcsvalue[31:24];
            if (byte_ready) begin
                nstate = IDLE;
            end 
        end

        endcase 

    end 
    if (cstate == PAD) begin
    //offers the serializer 0s to pad until it is ready (byte_ready)
    //once the serializer takes a 0, it sends that 0 as well to the CRC (crc_data_valid)
    //since the padding is also included in the CRC calculation
    //once the minimum is reached, the FSM shifts to the FCS state 
    tx_byte = 8'h00;
    byte_valid = 1'b1;

    if (byte_ready) begin
        crc_data_valid = 1'b1;

        if (frame_byte_count == 6'd59) begin
            nstate = FCS;
        end
    end
    end


end 




endmodule 