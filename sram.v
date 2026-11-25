// ============================================================================
// Module: sram.v
// Description: External 96-byte SRAM Model (Address Space 0x80 - 0xDF)
//              Synchronous write on posedge clk when cs_ram & we;
//              Combinational read drive onto data_bus when cs_ram & oe & !we.
// ============================================================================

module sram (
    input  wire       clk,
    input  wire [7:0] addr,      // Full 8-bit address (0x80 - 0xDF)
    input  wire       cs_ram,    // Active-high SRAM chip select
    input  wire       oe,        // Active-high output enable
    input  wire       we,        // Active-high write enable
    inout  wire [7:0] data_bus   // Bidirectional external data bus
);

    // 96 bytes: addresses 0x80 (128) through 0xDF (223)
    reg [7:0] ram [0:95];
    wire [7:0] offset = addr - 8'h80;

    integer i;
    initial begin
        for (i = 0; i < 96; i = i + 1)
            ram[i] = 8'h00;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (cs_ram && we)
            ram[offset] <= data_bus;
    end

    // Drive data bus only during a read cycle (not while writing)
    assign data_bus = (cs_ram && oe && !we) ? ram[offset] : 8'hZZ;

endmodule
