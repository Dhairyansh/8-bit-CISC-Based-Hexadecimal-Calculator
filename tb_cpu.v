`timescale 1ns / 1ps

// ============================================================================
// Testbench: tb_cpu.v
// Description: Comprehensive verification testbench for cpu_top covering
//              ADD, SUB, signed SUB, ZERO + JZ branch, 16-bit MUL (0xFF*0xFF),
//              memory-operand ADD [addr], and both IRQ_KEY & IRQ_CLR interrupts.
// ============================================================================

module tb_cpu;
    reg        clk;
    reg        rst;
    reg        irq_key;
    reg        irq_clr;

    wire [7:0] addr_bus;
    wire [7:0] data_bus;
    wire       mem_rd;
    wire       mem_wr;
    wire       io_rd;
    wire       io_wr;

    // 256-byte unified memory model for CPU-level testing
    reg  [7:0] mem [0:255];
    assign data_bus = mem_rd ? mem[addr_bus] : 8'hZZ;

    always @(posedge clk) begin
        if (mem_wr)
            mem[addr_bus] <= data_bus;
    end

    cpu_top uut (
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

    // 100 MHz clock (10 ns period)
    always #5 clk = ~clk;

    integer i;
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task check_mem;
        input [7:0]   addr;
        input [7:0]   expected;
        input [191:0] label;
        begin
            if (mem[addr] === expected) begin
                $display("PASS | %-22s | mem[0x%02h] = 0x%02h", label, addr, mem[addr]);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL | %-22s | mem[0x%02h] = 0x%02h (Expected 0x%02h)",
                         label, addr, mem[addr], expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);

        for (i = 0; i < 256; i = i + 1)
            mem[i] = 8'h00;

        // --------------------------------------------------------------------
        // Program in Memory (0x00 - 0x2F)
        // --------------------------------------------------------------------
        // TC01: 0x12 + 0x34 = 0x46 -> [0x80]
        mem[8'h00] = 8'h10; mem[8'h01] = 8'h12; // LDI A, #0x12
        mem[8'h02] = 8'h20;                     // MOV R0, A
        mem[8'h03] = 8'h10; mem[8'h04] = 8'h34; // LDI A, #0x34
        mem[8'h05] = 8'h30;                     // ADD R0 (A = 0x46)
        mem[8'h06] = 8'h12; mem[8'h07] = 8'h80; // STORE A, [0x80]

        // TC02: 0x20 - 0x50? Let's do 0x50 - 0x20 = 0x30 -> [0x81]
        mem[8'h08] = 8'h10; mem[8'h09] = 8'h20; // LDI A, #0x20
        mem[8'h0A] = 8'h20;                     // MOV R0, A (R0 = 0x20)
        mem[8'h0B] = 8'h10; mem[8'h0C] = 8'h50; // LDI A, #0x50
        mem[8'h0D] = 8'h40;                     // SUB R0 (A = 0x30)
        mem[8'h0E] = 8'h12; mem[8'h0F] = 8'h81; // STORE A, [0x81]

        // TC03: Signed/Negative SUB: 0x05 - 0x0A = 0xFB (-5) -> [0x82]
        mem[8'h10] = 8'h10; mem[8'h11] = 8'h0A; // LDI A, #0x0A
        mem[8'h12] = 8'h20;                     // MOV R0, A (R0 = 0x0A)
        mem[8'h13] = 8'h10; mem[8'h14] = 8'h05; // LDI A, #0x05
        mem[8'h15] = 8'h40;                     // SUB R0 (A = 0xFB, N=1, C=1)
        mem[8'h16] = 8'h12; mem[8'h17] = 8'h82; // STORE A, [0x82]

        // TC04: Zero result + JZ jump to 0x23 (skips STORE to [0x83])
        mem[8'h18] = 8'h10; mem[8'h19] = 8'h2A; // LDI A, #0x2A
        mem[8'h1A] = 8'h20;                     // MOV R0, A
        mem[8'h1B] = 8'h40;                     // SUB R0 (A = 0x00, Z=1)
        mem[8'h1C] = 8'h71; mem[8'h1D] = 8'h23; // JZ 0x23
        mem[8'h1E] = 8'h10; mem[8'h1F] = 8'h99; // LDI A, #0x99 (skipped)
        mem[8'h20] = 8'h12; mem[8'h21] = 8'h83; // STORE A, [0x83] (skipped)
        mem[8'h22] = 8'h70; mem[8'h23] = 8'h23; // (label 0x23)

        // TC05: Max 16-bit MUL: 0xFF * 0xFF = 0xFE01 -> LO=[0x84], HI=[0x85]
        mem[8'h23] = 8'h10; mem[8'h24] = 8'hFF; // LDI A, #0xFF
        mem[8'h25] = 8'h20;                     // MOV R0, A
        mem[8'h26] = 8'h50;                     // MUL R0 ({H,A} = 0xFE01)
        mem[8'h27] = 8'h12; mem[8'h28] = 8'h84; // STORE A, [0x84] (0x01)
        mem[8'h29] = 8'h23;                     // MOV A, H
        mem[8'h2A] = 8'h12; mem[8'h2B] = 8'h85; // STORE A, [0x85] (0xFE)

        // TC06: CISC Memory ADD [0x80]: 0x10 + 0x46 = 0x56 -> [0x86]
        mem[8'h2C] = 8'h10; mem[8'h2D] = 8'h10; // LDI A, #0x10
        mem[8'h2E] = 8'h31; mem[8'h2F] = 8'h80; // ADD [0x80] (A = 0x56)
        mem[8'h30] = 8'h12; mem[8'h31] = 8'h86; // STORE A, [0x86]

        // Enable interrupts and HALT while waiting for external IRQs
        mem[8'h32] = 8'h90;                     // EI
        mem[8'h33] = 8'hFF;                     // HALT

        // ISR 0: IRQ_KEY at vector 0x70 -> writes 0xA1 to [0x87], returns
        mem[8'h70] = 8'h10; mem[8'h71] = 8'hA1; // LDI A, #0xA1
        mem[8'h72] = 8'h12; mem[8'h73] = 8'h87; // STORE A, [0x87]
        mem[8'h74] = 8'h92;                     // RETI

        // ISR 1: IRQ_CLR at vector 0x78 -> writes 0xB2 to [0x88], re-enables IE, returns
        mem[8'h78] = 8'h10; mem[8'h79] = 8'hB2; // LDI A, #0xB2
        mem[8'h7A] = 8'h12; mem[8'h7B] = 8'h88; // STORE A, [0x88]
        mem[8'h7C] = 8'h90;                     // EI
        mem[8'h7D] = 8'h92;                     // RETI

        // --------------------------------------------------------------------
        // Stimulus Sequence
        // --------------------------------------------------------------------
        clk = 0; rst = 1; irq_key = 0; irq_clr = 0;
        #20 rst = 0;

        // Allow TC01-TC06 to execute and reach HALT
        #2500;

        check_mem(8'h80, 8'h46, "TC01_ADD");
        check_mem(8'h81, 8'h30, "TC02_SUB");
        check_mem(8'h82, 8'hFB, "TC03_SIGNED_SUB");
        check_mem(8'h83, 8'h00, "TC04_ZERO_JZ_SKIP");
        check_mem(8'h84, 8'h01, "TC05_MUL_LO_01");
        check_mem(8'h85, 8'hFE, "TC05_MUL_HI_FE");
        check_mem(8'h86, 8'h56, "TC06_ADD_MEM");

        // TC07: Trigger IRQ_KEY (INT0) while halted
        irq_key = 1; #40; irq_key = 0;
        #400;
        check_mem(8'h87, 8'hA1, "TC07_IRQ_KEY_ISR");

        // Re-enable interrupts (RETI cleared IE on entry), then trigger IRQ_CLR (INT1)
        // Note: In our control_unit.v, RETI sets ie_set=1, so IE is back on!
        irq_clr = 1; #40; irq_clr = 0;
        #400;
        check_mem(8'h88, 8'hB2, "TC08_IRQ_CLR_ISR");

        $display("------------------------------------------------------------");
        $display("SUMMARY: %0d PASSED, %0d FAILED", pass_cnt, fail_cnt);
        $finish;
    end
endmodule