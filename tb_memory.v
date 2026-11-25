
`timescale 1ns / 1ps

// ============================================================================
// Testbench: tb_memory.v
// Description: Verifies addr_decoder, flash_rom, and sram across ROM, SRAM,
//              and I/O address boundaries, plus read/write bus driving.
// ============================================================================

module tb_memory;
    reg        clk;
    reg  [7:0] addr_bus;
    reg        mem_rd;
    reg        mem_wr;
    reg        io_rd;
    reg        io_wr;

    wire       cs_rom, cs_ram, cs_io;
    wire       rom_oe, ram_oe, ram_we, io_oe, io_we;
    wire [7:0] data_bus;

    // Testbench driver for write cycles
    reg        tb_drive;
    reg  [7:0] tb_wdata;
    assign data_bus = tb_drive ? tb_wdata : 8'hZZ;

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

    always #5 clk = ~clk;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    initial begin
        $dumpfile("tb_memory.vcd");
        $dumpvars(0, tb_memory);

        clk = 0; addr_bus = 8'h00;
        mem_rd = 0; mem_wr = 0; io_rd = 0; io_wr = 0;
        tb_drive = 0; tb_wdata = 8'h00;
        #10;

        // 1. Read Flash ROM at 0x01 (expected 0x12)
        addr_bus = 8'h01; mem_rd = 1;
        #5;
        if (cs_rom && !cs_ram && !cs_io && data_bus === 8'h12) begin
            $display("PASS | ROM_READ_0x01     | data=0x%02h", data_bus);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL | ROM_READ_0x01     | cs_rom=%b data=0x%02h", cs_rom, data_bus);
            fail_cnt = fail_cnt + 1;
        end
        #5; mem_rd = 0;

        // 2. Attempt write to ROM at 0x01 (should not alter ROM)
        addr_bus = 8'h01; tb_wdata = 8'hEE; tb_drive = 1; mem_wr = 1;
        @(posedge clk); #1;
        mem_wr = 0; tb_drive = 0;
        #5; mem_rd = 1; #5;
        if (data_bus === 8'h12) begin
            $display("PASS | ROM_WRITE_PROTECT | data=0x%02h", data_bus);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL | ROM_WRITE_PROTECT | data=0x%02h", data_bus);
            fail_cnt = fail_cnt + 1;
        end
        mem_rd = 0; #5;

        // 3. Write 0x5A to SRAM at 0x80 and 0xC3 at 0xDF, then read back
        addr_bus = 8'h80; tb_wdata = 8'h5A; tb_drive = 1; mem_wr = 1;
        @(posedge clk); #1;
        mem_wr = 0; tb_drive = 0;

        addr_bus = 8'hDF; tb_wdata = 8'hC3; tb_drive = 1; mem_wr = 1;
        @(posedge clk); #1;
        mem_wr = 0; tb_drive = 0;

        addr_bus = 8'h80; mem_rd = 1; #5;
        if (cs_ram && !cs_rom && data_bus === 8'h5A) begin
            $display("PASS | SRAM_RW_0x80      | data=0x%02h", data_bus);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL | SRAM_RW_0x80      | cs_ram=%b data=0x%02h", cs_ram, data_bus);
            fail_cnt = fail_cnt + 1;
        end
        mem_rd = 0; #5;

        addr_bus = 8'hDF; mem_rd = 1; #5;
        if (cs_ram && data_bus === 8'hC3) begin
            $display("PASS | SRAM_RW_0xDF      | data=0x%02h", data_bus);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL | SRAM_RW_0xDF      | data=0x%02h", data_bus);
            fail_cnt = fail_cnt + 1;
        end
        mem_rd = 0; #5;

        // 4. Verify I/O region decode (0xE0) leaves data_bus undriven (8'hZZ)
        addr_bus = 8'hE0; io_rd = 1; #5;
        if (cs_io && !cs_rom && !cs_ram && data_bus === 8'hZZ) begin
            $display("PASS | IO_DECODE_0xE0    | cs_io=1 bus=ZZ");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL | IO_DECODE_0xE0    | cs_io=%b bus=0x%02h", cs_io, data_bus);
            fail_cnt = fail_cnt + 1;
        end
        io_rd = 0; #5;

        $display("------------------------------------------------------------");
        $display("MEMORY SUMMARY: %0d PASSED, %0d FAILED", pass_cnt, fail_cnt);
        $finish;
    end
endmodule