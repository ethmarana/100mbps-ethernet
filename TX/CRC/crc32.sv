module crc32 (
    input logic clk,
    input logic reset,
    input logic clear, 
    input logic [7:0] data_in,
    input logic data_valid,
    output logic [31:0] crc_out
);

//updates the running CRC-32 by a right shift + XOR for one input byte perform CRC32 calculation
//FCS is the final running total of the CRC calculation, represented as 32 bits
//the reciever recalculates the FCS, and if they don't match 
//the reciever knows that there was an error in the transmission or recieving process

logic [31:0] crcreg, nextcrc;
logic feedback; 
always_ff @(posedge clk) begin
    if (reset || clear) begin
        crcreg <= 32'hFFFFFFFF;
    end else if (data_valid) begin
        crcreg <= nextcrc; 
    end 
    
end

always_comb begin
    nextcrc = crcreg;
    for (int i = 0; i < 8; i++) begin
        feedback = data_in[i] ^ nextcrc[0];
        nextcrc = nextcrc >> 1; 
        if (feedback) begin
            nextcrc = nextcrc ^ 32'hEDB88320; 
        end 
    end 
end 

always_comb begin
    crc_out = ~crcreg; 
end 

endmodule 


