module syncfifo #(parameter int data = 8, parameter int regamt = 8) (
    input logic clk,
    input logic [data-1:0] datain,
    input logic write,
    input logic read,
    input logic reset, 
    output logic [data-1:0] readvalue,
    output logic full,
    output logic empty,
    output logic almostempty,
    output logic almostfull

);

//a basic synchronous fifo made earlier as a practice problem,
//now being integrated into this larger project 

logic [$clog2(regamt)-1:0] writeptr;
logic [$clog2(regamt)-1:0] readptr;
logic [$clog2(regamt+1)-1:0] count; 
logic [data-1:0] mem [0:regamt-1];
logic validwrite; 
logic validread;

always_ff @(posedge clk) begin
    if (reset) begin 
        writeptr <= '0;
        readptr <= '0;
        count <= '0;
        readvalue <= '0;
    end else begin 
        if (validwrite) begin
            mem[writeptr] <= datain;
            if (writeptr == regamt-1) begin
                writeptr <= '0;
            end 
            else begin
                writeptr <= writeptr + 1; 
            end 
        end 
        if (validread) begin
            readvalue <= mem[readptr];
            if (readptr == regamt-1) begin
                readptr <= '0;
            end else begin
                readptr <= readptr + 1;
            end 
        end 
        if (validwrite && !validread) begin
            count <= count + 1; 
        end 
        if (validread && !validwrite) begin
            count <= count - 1;
        end 
    end 

end 
    

always_comb begin
    empty = '0;
    full = '0;
    validread = '0;
    validwrite = '0;
    almostempty = '0;
    almostfull = '0;
    validread = read && !empty;
    validwrite = write && !full;
    if (count == 0) begin
        empty = 1'b1; 
    end
    if (count == regamt) begin
        full = 1'b1;
    end 
    if (count <= 6) begin
        almostempty = 1'b1;
    end 
    if (count >= 28) begin
        almostfull = 1'b1;
    end 

end 




endmodule 

