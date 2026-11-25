// ============================================================================
// Module: flash_rom.v
// Description: External 128-byte Flash ROM Model (Address Space 0x00 - 0x7F)
//              Read-only during normal operation; drives data_bus when cs_rom & oe.
// ============================================================================

module flash_rom (
    input  wire [6:0] addr,      // Offset within 128-byte ROM (addr_bus[6:0])
    input  wire       cs_rom,    // Active-high Flash ROM chip select
    input  wire       oe,        // Active-high output enable
    inout  wire [7:0] data_bus   // Bidirectional external data bus
);

    reg [7:0] rom [0:127];
    integer i;

    initial begin
        // Default safe contents (NOP = 0x00)
        for (i = 0; i < 128; i = i + 1)
            rom[i] = 8'h00;

        // Optional hex file load (uncomment or pass +define+USE_HEX_FILE if desired)
        // $readmemh("firmware.hex", rom);

        // Sample Calculator Program at 0x00:
        // (0x12 + 0x34) -> store at 0x80; (0x06 * 0x07) -> store at 0x81/0x82
        rom[7'h00] = 8'h10; rom[7'h01] = 8'h12; // LDI A, #0x12
        rom[7'h02] = 8'h20;                     // MOV R0, A
        rom[7'h03] = 8'h10; rom[7'h04] = 8'h34; // LDI A, #0x34
        rom[7'h05] = 8'h30;                     // ADD R0 (0x46)
        rom[7'h06] = 8'h12; rom[7'h07] = 8'h80; // STORE A, [0x80]
        rom[7'h08] = 8'hFF;                     // HALT
    end

    // Drive data bus only when selected and output-enabled
    assign data_bus = (cs_rom && oe) ? rom[addr] : 8'hZZ;

endmodule
