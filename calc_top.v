
// ============================================================================
// Module: calc_top.v
// Description: Top-Level 8-bit CISC Hexadecimal Calculator System
//              Integrates cpu_top, addr_decoder, flash_rom, sram, keypad_if,
//              and display_ctrl with bidirectional external data_bus.
// ============================================================================

module calc_top #(
    parameter integer DEBOUNCE_MAX = 4,
    parameter integer MUX_DIV_MAX  = 2
)(
    input  wire       clk,
    input  wire       rst,

    // Keypad & Pushbutton Inputs
    input  wire [3:0] keypad_col,
    output wire [3:0] keypad_row,
    input  wire       btn_add,
    input  wire       btn_sub,
    input  wire       btn_mul,
    input  wire       btn_eq,
    input  wire       btn_clr,

    // Common-Cathode 4-Digit 7-Segment Display Outputs
    output wire [6:0] seg,          // Active-high {g,f,e,d,c,b,a}
    output wire [3:0] dig_en,       // Active-low digit enables (3..0)

    // Exposed Bus Signals (useful for top-level observation & verification)
    output wire [7:0] addr_bus,
    inout  wire [7:0] data_bus,
    output wire       mem_rd,
    output wire       mem_wr,
    output wire       io_rd,
    output wire       io_wr
);

    wire       cs_rom, cs_ram, cs_io;
    wire       rom_oe, ram_oe, ram_we, io_oe, io_we;
    wire       irq_key, irq_clr;

    // ------------------------------------------------------------------------
    // 1. 8-bit CISC Microprocessor Core
    // ------------------------------------------------------------------------
    cpu_top u_cpu (
        .clk      (clk),
        .rst      (rst),
        .irq_key  (irq_key),
        .irq_clr  (irq_clr),
        .addr_bus (addr_bus),
        .data_bus (data_bus),
        .mem_rd   (mem_rd),
        .mem_wr   (mem_wr),
        .io_rd    (io_rd),
        .io_wr    (io_wr)
    );

    // ------------------------------------------------------------------------
    // 2. Memory & I/O Address Decoder
    // ------------------------------------------------------------------------
    addr_decoder u_dec (
        .addr_bus (addr_bus),
        .mem_rd   (mem_rd),
        .mem_wr   (mem_wr),
        .io_rd    (io_rd),
        .io_wr    (io_wr),
        .cs_rom   (cs_rom),
        .cs_ram   (cs_ram),
        .cs_io    (cs_io),
        .rom_oe   (rom_oe),
        .ram_oe   (ram_oe),
        .ram_we   (ram_we),
        .io_oe    (io_oe),
        .io_we    (io_we)
    );

    // ------------------------------------------------------------------------
    // 3. External Flash ROM (0x00 - 0x7F) & External SRAM (0x80 - 0xDF)
    // ------------------------------------------------------------------------
    flash_rom u_rom (
        .addr     (addr_bus[6:0]),
        .cs_rom   (cs_rom),
        .oe       (rom_oe),
        .data_bus (data_bus)
    );

    sram u_ram (
        .clk      (clk),
        .addr     (addr_bus),
        .cs_ram   (cs_ram),
        .oe       (ram_oe),
        .we       (ram_we),
        .data_bus (data_bus)
    );

    // ------------------------------------------------------------------------
    // 4. Hexadecimal Keypad Interface (Port 0xE0)
    // ------------------------------------------------------------------------
    keypad_if #(
        .DEBOUNCE_MAX(DEBOUNCE_MAX)
    ) u_keypad (
        .clk        (clk),
        .rst        (rst),
        .cs_io      (cs_io),
        .io_rd      (io_oe),
        .port_sel   (addr_bus[1:0]),
        .data_bus   (data_bus),
        .keypad_col (keypad_col),
        .keypad_row (keypad_row),
        .btn_add    (btn_add),
        .btn_sub    (btn_sub),
        .btn_mul    (btn_mul),
        .btn_eq     (btn_eq),
        .btn_clr    (btn_clr),
        .irq_key    (irq_key),
        .irq_clr    (irq_clr)
    );

    // ------------------------------------------------------------------------
    // 5. Common-Cathode 4-Digit 7-Segment Display Controller (Ports 0xE1-0xE3)
    // ------------------------------------------------------------------------
    display_ctrl #(
        .MUX_DIV_MAX(MUX_DIV_MAX)
    ) u_display (
        .clk      (clk),
        .rst      (rst),
        .cs_io    (cs_io),
        .io_wr    (io_we),
        .port_sel (addr_bus[1:0]),
        .data_in  (data_bus),
        .seg      (seg),
        .dig_en   (dig_en)
    );

endmodule