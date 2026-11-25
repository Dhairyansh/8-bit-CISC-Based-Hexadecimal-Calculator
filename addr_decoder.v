// ============================================================================
// Module: addr_decoder.v
// Description: Combinational Memory & I/O Address Decoder for 8-bit Address Bus
//              0x00 - 0x7F (128B): External Flash ROM (cs_rom)
//              0x80 - 0xDF (96B) : External SRAM      (cs_ram)
//              0xE0 - 0xFF (32B) : I/O Space        (cs_io)
// ============================================================================

module addr_decoder (
    input  wire [7:0] addr_bus,
    input  wire       mem_rd,
    input  wire       mem_wr,
    input  wire       io_rd,
    input  wire       io_wr,

    // Chip selects
    output wire       cs_rom,
    output wire       cs_ram,
    output wire       cs_io,

    // Qualified device control strobes
    output wire       rom_oe,
    output wire       ram_oe,
    output wire       ram_we,
    output wire       io_oe,
    output wire       io_we
);

    // Non-overlapping region decode using upper 3 address bits
    assign cs_rom = ~addr_bus[7];
    assign cs_ram =  addr_bus[7] & ~(addr_bus[6] & addr_bus[5]);
    assign cs_io  =  addr_bus[7] &  addr_bus[6] &  addr_bus[5];

    // Qualified strobes
    assign rom_oe = cs_rom & mem_rd;
    assign ram_oe = cs_ram & mem_rd;
    assign ram_we = cs_ram & mem_wr;
    assign io_oe  = cs_io  & io_rd;
    assign io_we  = cs_io  & io_wr;

endmodule
