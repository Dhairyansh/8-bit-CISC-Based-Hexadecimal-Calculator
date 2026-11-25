`timescale 1ns / 1ps

module tb_keypad;
    reg        clk, rst;
    reg        cs_io, io_rd;
    reg  [1:0] port_sel;
    reg  [3:0] keypad_col;
    wire [3:0] keypad_row;
    reg        btn_add, btn_sub, btn_mul, btn_eq, btn_clr;
    wire [7:0] data_bus;
    wire       irq_key, irq_clr;

    keypad_if #(.DEBOUNCE_MAX(3)) uut (
        .clk(clk), .rst(rst),
        .cs_io(cs_io), .io_rd(io_rd), .port_sel(port_sel),
        .data_bus(data_bus),
        .keypad_col(keypad_col), .keypad_row(keypad_row),
        .btn_add(btn_add), .btn_sub(btn_sub), .btn_mul(btn_mul),
        .btn_eq(btn_eq), .btn_clr(btn_clr),
        .irq_key(irq_key), .irq_clr(irq_clr)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_keypad.vcd");
        $dumpvars(0, tb_keypad);

        clk = 0; rst = 1; cs_io = 0; io_rd = 0; port_sel = 2'b00;
        keypad_col = 4'b0000;
        btn_add = 0; btn_sub = 0; btn_mul = 0; btn_eq = 0; btn_clr = 0;
        #20 rst = 0;

        // 1. Short bounce (1 cycle < DEBOUNCE_MAX=3) should NOT trigger irq_key
        keypad_col = 4'b0011; #10; keypad_col = 4'b0000; #40;
        if (!irq_key)
            $display("PASS | DEBOUNCE_FILTER | bounce ignored");
        else
            $display("FAIL | DEBOUNCE_FILTER | false irq_key=%b", irq_key);

        // 2. Press key at Row 2, Col 2 -> Hex 'A' (4'hA)
        wait (keypad_row == 4'b0100);
        keypad_col = 4'b0100;
        #80; // Hold past debounce window
        if (irq_key)
            $display("PASS | KEY_DETECT_A    | irq_key=1");
        else
            $display("FAIL | KEY_DETECT_A    | irq_key=0");

        // CPU reads port 0xE0
        cs_io = 1; io_rd = 1; port_sel = 2'b00;
        #10;
        if (data_bus === 8'h0A)
            $display("PASS | KEY_CODE_0A     | data_bus=0x%02h", data_bus);
        else
            $display("FAIL | KEY_CODE_0A     | data_bus=0x%02h", data_bus);
        @(posedge clk); #1;
        cs_io = 0; io_rd = 0; keypad_col = 4'b0000;
        #20;
        if (!irq_key)
            $display("PASS | IRQ_KEY_CLEAR   | irq_key cleared after read");
        else
            $display("FAIL | IRQ_KEY_CLEAR   | irq_key still high");

        // 3. Press CLR button -> irq_clr
        btn_clr = 1; #80; btn_clr = 0;
        #20;
        if (irq_clr)
            $display("PASS | IRQ_CLR_ASSERT  | irq_clr=1");
        else
            $display("FAIL | IRQ_CLR_ASSERT  | irq_clr=0");

        $finish;
    end
endmodule
