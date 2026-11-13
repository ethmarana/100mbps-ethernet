just create a basic 100 mbps ping-pong
store and forward to learn basic mac shit

upgrade into cut thru and stuff

-> make a packet parser!

full stack udp / ip / packet parsing 

                  ┌───────────────────────────────────────────┐
                  │          PHYSICAL ETHERNET WIRE           │
                  └─────────────────────┬─────────────────────┘
                                        │ (MII/RMII Analog/Bits)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: THE CUSTOM MAC (Clock Domain A: 25 MHz PHY Clock)                          │
│ • Detects Preamble (0x55) & SFD (0xD5)                                              │
│ • Byte/Nibble Aligner                                                               │
│ • Live CRC-32 Validation Engine                                                     │
└───────────────────────────────────────┬─────────────────────────────────────────────┘
                                        │ (Raw valid byte stream)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 2: THE ISOLATION BUFFER (Asynchronous CDC FIFO)                               │
│ • Crosses data safely from the 25 MHz PHY clock up to your fast System Clock        │
│ • Outputs an industry-standard AXI-Stream interface (tdata, tvalid, tready, tlast)  │
└───────────────────────────────────────┬─────────────────────────────────────────────┘
                                        │ (AXI-Stream Protocol @ 100MHz+)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 3: THE PACKET PARSER / ACCELERATOR (Clock Domain B: 100-200 MHz System Clock) │
│ • Strips Ethernet, IPv4, and UDP Headers on-the-fly                                 │
│ • Low-latency, multi-stage parallel lookahead logic                                  │
│ • Immediate hardware trigger / Action strobe                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘


[ Analog Differential Pins ]  <-- Serial Bitstream (e.g., 125 MHz or 1.25 GHz)
          │
  ┌───────▼───────┐
  │    SerDes     │           <-- Deserializes data, recovers the clock
  └───────┬───────┘
          │ (e.g., 5-bit or 10-bit Parallel Data)
  ┌───────▼───────┐
  │  PCS Layer    │           <-- Handles 4B5B/8B10B decoding, byte alignment
  └───────┬───────┘
          │ (e.g., 4-bit MII or 8-bit GMII)
  ┌───────▼───────┐
  │ Ethernet MAC  │           <-- Preamble filtering, CRC32 verification
  └───────┬───────┘
          │ (Streaming Interface: e.g., AXI-Stream)
  ┌───────▼───────┐
  │ IPv4 Parser   │           <-- Validates IP Header, checks Length/Checksums
  └───────┬───────┘
          │
  ┌───────▼───────┐
  │  UDP Parser   │           <-- Extracts Destination Port and User Payload
  └───────┬───────┘
          │
[ Application Logic ]         <-- Processes pure UDP payload data