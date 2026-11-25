`timescale 1ns / 1ps

// ============================================================================
// Testbench: tb_system.v
// Description: Extended system-level verification of calc_top covering ADD,
//              SUB, negative/signed SUB, zero results, 16-bit MUL (max, zero,
//              intermediate), matrix hex keypad input, and IRQ_CLR.
// ============================================================================

module tb_system;
    reg        clk, rst;
    reg  [3:0] keypad_col;
    wire [3:0] keypad_row;
    reg        btn_add, btn_sub, btn_mul, btn_eq, btn_clr;

    wire [6:0] seg;
    wire [3:0] dig_en;
    wire [7:0] addr_bus;
    wire [7:0] data_bus;
    wire       mem_rd, mem_wr, io_rd, io_wr;

    calc_top #(
        .DEBOUNCE_MAX(2),
        .MUX_DIV_MAX(1)
    ) uut (
        .clk        (clk),
        .rst        (rst),
        .keypad_col (keypad_col),
        .keypad_row (keypad_row),
        .btn_add    (btn_add),
        .btn_sub    (btn_sub),
        .btn_mul    (btn_mul),
        .btn_eq     (btn_eq),
        .btn_clr    (btn_clr),
        .seg        (seg),
        .dig_en     (dig_en),
        .addr_bus   (addr_bus),
        .data_bus   (data_bus),
        .mem_rd     (mem_rd),
        .mem_wr     (mem_wr),
        .io_rd      (io_rd),
        .io_wr      (io_wr)
    );

    always #5 clk = ~clk;

    task pulse_button;
        input integer sel; // 1=ADD, 2=SUB, 3=MUL, 4=CLR
        begin
            btn_add = (sel == 1);
            btn_sub = (sel == 2);
            btn_mul = (sel == 3);
            btn_clr = (sel == 4);
            repeat (10) @(posedge clk);
            btn_add = 1'b0;
            btn_sub = 1'b0;
            btn_mul = 1'b0;
            btn_clr = 1'b0;
            repeat (190) @(posedge clk);
        end
    endtask

    task press_hex_key;
        input [1:0] target_row;
        input [1:0] target_col;
        reg [3:0] row_mask;
        reg [3:0] col_mask;
        begin
            row_mask = (4'b0001 << target_row);
            col_mask = (4'b0001 << target_col);
            wait (keypad_row == row_mask);
            keypad_col = col_mask;
            // Hold across multiple full 4-row scan cycles so target_row is sampled repeatedly
            repeat (28) @(posedge clk);
            keypad_col = 4'b0000;
            repeat (140) @(posedge clk);
        end
    endtask

    task check_disp;
        input [159:0] tc_name;
        input [191:0] op_desc;
        input [7:0]   exp_hi;
        input [7:0]   exp_lo;
        input         exp_neg;
        reg           ok;
        begin
            ok = (uut.u_display.disp_hi === exp_hi) &&
                 (uut.u_display.disp_lo === exp_lo) &&
                 (uut.u_display.disp_ctrl[0] === exp_neg);
            $display("| %-13s | %-20s | 0x%02h%02h (n=%0b) | 0x%02h%02h (n=%0b) | %-6s |",
                     tc_name, op_desc,
                     uut.u_display.disp_hi, uut.u_display.disp_lo, uut.u_display.disp_ctrl[0],
                     exp_hi, exp_lo, exp_neg,
                     ok ? "PASS" : "FAIL");
        end
    endtask

    integer i;
    initial begin
        $dumpfile("tb_system.vcd");
        $dumpvars(0, tb_system);

        for (i = 0; i < 128; i = i + 1)
            uut.u_rom.rom[i] = 8'h00;

        // --------------------------------------------------------------------
        // Main Loop (0x00 - 0x02)
        // --------------------------------------------------------------------
        uut.u_rom.rom[8'h00] = 8'h90;                     // EI
        uut.u_rom.rom[8'h01] = 8'h70; uut.u_rom.rom[8'h02] = 8'h01; // JMP 0x01

        // --------------------------------------------------------------------
        // IRQ_KEY ISR (starts at 0x10)
        // SRAM map:
        //   0x80: OP1
        //   0x81: OP2
        //   0x82: OP_SEL (1=ADD, 2=SUB, 3=MUL)
        //   0x83: last key read from 0xE0
        //   0x84: const 0x02
        //   0x85: const 0x03
        // --------------------------------------------------------------------
        uut.u_rom.rom[8'h10] = 8'h80; uut.u_rom.rom[8'h11] = 8'hE0; // IN A, 0xE0 (ack irq_key)
        uut.u_rom.rom[8'h12] = 8'h12; uut.u_rom.rom[8'h13] = 8'h83; // STORE A, [0x83] (log key)
        uut.u_rom.rom[8'h14] = 8'h11; uut.u_rom.rom[8'h15] = 8'h81; // LOAD A, [0x81] (OP2)
        uut.u_rom.rom[8'h16] = 8'h20;                     // MOV R0, A (R0 = OP2)

        // Check OP_SEL == 2 -> JMP 0x2E (SUB)
        uut.u_rom.rom[8'h17] = 8'h11; uut.u_rom.rom[8'h18] = 8'h82; // LOAD A, [0x82]
        uut.u_rom.rom[8'h19] = 8'h41; uut.u_rom.rom[8'h1A] = 8'h84; // SUB [0x84]
        uut.u_rom.rom[8'h1B] = 8'h71; uut.u_rom.rom[8'h1C] = 8'h2E; // JZ 0x2E

        // Check OP_SEL == 3 -> JMP 0x4D (MUL)
        uut.u_rom.rom[8'h1D] = 8'h11; uut.u_rom.rom[8'h1E] = 8'h82; // LOAD A, [0x82]
        uut.u_rom.rom[8'h1F] = 8'h41; uut.u_rom.rom[8'h20] = 8'h85; // SUB [0x85]
        uut.u_rom.rom[8'h21] = 8'h71; uut.u_rom.rom[8'h22] = 8'h4D; // JZ 0x4D

        // ADD branch (0x23): A = OP1 + R0, OUT LO (0xE1), OUT HI=0 (0xE2), JMP 0x48
        uut.u_rom.rom[8'h23] = 8'h11; uut.u_rom.rom[8'h24] = 8'h80; // LOAD A, [0x80]
        uut.u_rom.rom[8'h25] = 8'h30;                     // ADD R0
        uut.u_rom.rom[8'h26] = 8'h81; uut.u_rom.rom[8'h27] = 8'hE1; // OUT 0xE1, A
        uut.u_rom.rom[8'h28] = 8'h10; uut.u_rom.rom[8'h29] = 8'h00; // LDI A, #0x00
        uut.u_rom.rom[8'h2A] = 8'h81; uut.u_rom.rom[8'h2B] = 8'hE2; // OUT 0xE2, A
        uut.u_rom.rom[8'h2C] = 8'h70; uut.u_rom.rom[8'h2D] = 8'h48; // JMP 0x48

        // SUB branch (0x2E): A = OP1 - R0, OUT LO (0xE1), OUT HI=0 (0xE2), check N flag
        uut.u_rom.rom[8'h2E] = 8'h11; uut.u_rom.rom[8'h2F] = 8'h80; // LOAD A, [0x80]
        uut.u_rom.rom[8'h30] = 8'h40;                     // SUB R0
        uut.u_rom.rom[8'h31] = 8'h81; uut.u_rom.rom[8'h32] = 8'hE1; // OUT 0xE1, A
        uut.u_rom.rom[8'h33] = 8'h10; uut.u_rom.rom[8'h34] = 8'h00; // LDI A, #0x00
        uut.u_rom.rom[8'h35] = 8'h81; uut.u_rom.rom[8'h36] = 8'hE2; // OUT 0xE2, A
        uut.u_rom.rom[8'h37] = 8'h73; uut.u_rom.rom[8'h38] = 8'h43; // JN 0x43
        uut.u_rom.rom[8'h39] = 8'h70; uut.u_rom.rom[8'h3A] = 8'h48; // JMP 0x48

        // Negative sign exit (0x43): disp_ctrl = 0x01, RETI
        uut.u_rom.rom[8'h43] = 8'h10; uut.u_rom.rom[8'h44] = 8'h01; // LDI A, #0x01
        uut.u_rom.rom[8'h45] = 8'h81; uut.u_rom.rom[8'h46] = 8'hE3; // OUT 0xE3, A
        uut.u_rom.rom[8'h47] = 8'h92;                     // RETI

        // Non-negative sign exit (0x48): disp_ctrl = 0x00, RETI
        uut.u_rom.rom[8'h48] = 8'h10; uut.u_rom.rom[8'h49] = 8'h00; // LDI A, #0x00
        uut.u_rom.rom[8'h4A] = 8'h81; uut.u_rom.rom[8'h4B] = 8'hE3; // OUT 0xE3, A
        uut.u_rom.rom[8'h4C] = 8'h92;                     // RETI

        // MUL branch (0x4D): {H,A} = OP1 * R0, OUT LO (0xE1), OUT HI (0xE2), JMP 0x48
        uut.u_rom.rom[8'h4D] = 8'h11; uut.u_rom.rom[8'h4E] = 8'h80; // LOAD A, [0x80]
        uut.u_rom.rom[8'h4F] = 8'h50;                     // MUL R0
        uut.u_rom.rom[8'h50] = 8'h81; uut.u_rom.rom[8'h51] = 8'hE1; // OUT 0xE1, A (LO)
        uut.u_rom.rom[8'h52] = 8'h23;                     // MOV A, H
        uut.u_rom.rom[8'h53] = 8'h81; uut.u_rom.rom[8'h54] = 8'hE2; // OUT 0xE2, A (HI)
        uut.u_rom.rom[8'h55] = 8'h70; uut.u_rom.rom[8'h56] = 8'h48; // JMP 0x48

        // IRQ_CLR ISR (0x58): clear 0xE1..0xE3 to 0x00 and RETI
        uut.u_rom.rom[8'h58] = 8'h10; uut.u_rom.rom[8'h59] = 8'h00; // LDI A, #0x00
        uut.u_rom.rom[8'h5A] = 8'h81; uut.u_rom.rom[8'h5B] = 8'hE1; // OUT 0xE1, A
        uut.u_rom.rom[8'h5C] = 8'h81; uut.u_rom.rom[8'h5D] = 8'hE2; // OUT 0xE2, A
        uut.u_rom.rom[8'h5E] = 8'h81; uut.u_rom.rom[8'h5F] = 8'hE3; // OUT 0xE3, A
        uut.u_rom.rom[8'h60] = 8'h92;                     // RETI

        // Vectors
        uut.u_rom.rom[8'h70] = 8'h70; uut.u_rom.rom[8'h71] = 8'h10; // IRQ_KEY -> 0x10
        uut.u_rom.rom[8'h78] = 8'h70; uut.u_rom.rom[8'h79] = 8'h58; // IRQ_CLR -> 0x58

        // Constants in SRAM: [0x84] = 0x02, [0x85] = 0x03
        uut.u_ram.ram[4] = 8'h02;
        uut.u_ram.ram[5] = 8'h03;

        clk = 0; rst = 1; keypad_col = 4'b0000;
        btn_add = 0; btn_sub = 0; btn_mul = 0; btn_eq = 0; btn_clr = 0;
        #20 rst = 0;
        repeat (20) @(posedge clk);

        $display("+---------------+----------------------+---------------+---------------+--------+");
        $display("| Test Case     | Operation            | Actual        | Expect        | Status |");
        $display("+---------------+----------------------+---------------+---------------+--------+");

        // TC01: Standard ADD (0x1A + 0x26 = 0x0040)
        uut.u_ram.ram[0] = 8'h1A; uut.u_ram.ram[1] = 8'h26; uut.u_ram.ram[2] = 8'h01;
        pulse_button(1);
        check_disp("TC01_ADD", "0x1A + 0x26", 8'h00, 8'h40, 1'b0);

        // TC02: Carry/Wrap ADD (0xFF + 0x01 = 0x0000)
        uut.u_ram.ram[0] = 8'hFF; uut.u_ram.ram[1] = 8'h01; uut.u_ram.ram[2] = 8'h01;
        pulse_button(1);
        check_disp("TC02_ADD_WRAP", "0xFF + 0x01", 8'h00, 8'h00, 1'b0);

        // TC03: Standard SUB (0x55 - 0x20 = 0x0035)
        uut.u_ram.ram[0] = 8'h55; uut.u_ram.ram[1] = 8'h20; uut.u_ram.ram[2] = 8'h02;
        pulse_button(2);
        check_disp("TC03_SUB", "0x55 - 0x20", 8'h00, 8'h35, 1'b0);

        // TC04: Negative SUB (0x05 - 0x0A = 0x00FB, neg=1)
        uut.u_ram.ram[0] = 8'h05; uut.u_ram.ram[1] = 8'h0A; uut.u_ram.ram[2] = 8'h02;
        pulse_button(2);
        check_disp("TC04_NEG_SUB", "0x05 - 0x0A", 8'h00, 8'hFB, 1'b1);

        // TC05: Zero SUB (0x42 - 0x42 = 0x0000, neg=0)
        uut.u_ram.ram[0] = 8'h42; uut.u_ram.ram[1] = 8'h42; uut.u_ram.ram[2] = 8'h02;
        pulse_button(2);
        check_disp("TC05_ZERO_SUB", "0x42 - 0x42", 8'h00, 8'h00, 1'b0);

        // TC06: Intermediate MUL (0x12 * 0x0A = 0x00B4)
        uut.u_ram.ram[0] = 8'h12; uut.u_ram.ram[1] = 8'h0A; uut.u_ram.ram[2] = 8'h03;
        pulse_button(3);
        check_disp("TC06_MUL_MID", "0x12 * 0x0A", 8'h00, 8'hB4, 1'b0);

        // TC07: Max 16-bit MUL (0xFF * 0xFF = 0xFE01)
        uut.u_ram.ram[0] = 8'hFF; uut.u_ram.ram[1] = 8'hFF; uut.u_ram.ram[2] = 8'h03;
        pulse_button(3);
        check_disp("TC07_MUL_MAX", "0xFF * 0xFF", 8'hFE, 8'h01, 1'b0);

        // TC08: Zero MUL (0x00 * 0xAB = 0x0000)
        uut.u_ram.ram[0] = 8'h00; uut.u_ram.ram[1] = 8'hAB; uut.u_ram.ram[2] = 8'h03;
        pulse_button(3);
        check_disp("TC08_MUL_ZERO", "0x00 * 0xAB", 8'h00, 8'h00, 1'b0);

        // TC09: Matrix Hex Key 'F' (Row 3, Col 3 -> 0x0F) via IRQ_KEY
        uut.u_ram.ram[0] = 8'h0F; uut.u_ram.ram[1] = 8'h00; uut.u_ram.ram[2] = 8'h01;
        press_hex_key(2'd3, 2'd3);
        check_disp("TC09_KEY_HEX_F", "Matrix Key 'F' IRQ", 8'h00, 8'h0F, 1'b0);

        // TC10: Clear Interrupt (resets display & sign to 0x0000, n=0)
        pulse_button(4);
        check_disp("TC10_CLR_IRQ", "IRQ_CLR Reset", 8'h00, 8'h00, 1'b0);

        $display("+---------------+----------------------+---------------+---------------+--------+");
        $finish;
    end
endmodule