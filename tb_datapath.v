`timescale 1ns / 1ps

module tb_datapath;
    reg        clk, rst;
    reg  [3:0] bus_sel;
    reg  [2:0] alu_op;
    reg        alu_b_sel, h_src_sel, mdr_src_sel, flags_src_sel;
    reg        pc_load, pc_inc, ir_load, a_load, h_load, r0_load, r1_load;
    reg        mar_load, mdr_load, flags_load, pc_save_load, flags_save_load;
    reg        data_bus_oe;
    reg  [7:0] irq_vector;

    wire [7:0] ir_out;
    wire [3:0] flags_out;
    wire [7:0] addr_bus;
    wire [7:0] data_bus;

    // External testbench driver for bidirectional data_bus
    reg        tb_drive_bus;
    reg  [7:0] tb_data_out;
    assign data_bus = tb_drive_bus ? tb_data_out : 8'hZZ;

    datapath uut (
        .clk(clk), .rst(rst),
        .bus_sel(bus_sel), .alu_op(alu_op),
        .alu_b_sel(alu_b_sel), .h_src_sel(h_src_sel),
        .mdr_src_sel(mdr_src_sel), .flags_src_sel(flags_src_sel),
        .pc_load(pc_load), .pc_inc(pc_inc), .ir_load(ir_load),
        .a_load(a_load), .h_load(h_load), .r0_load(r0_load), .r1_load(r1_load),
        .mar_load(mar_load), .mdr_load(mdr_load), .flags_load(flags_load),
        .pc_save_load(pc_save_load), .flags_save_load(flags_save_load),
        .data_bus_oe(data_bus_oe), .irq_vector(irq_vector),
        .ir_out(ir_out), .flags_out(flags_out),
        .addr_bus(addr_bus), .data_bus(data_bus)
    );

    // 100 MHz clock (10ns period)
    always #5 clk = ~clk;

    task clear_ctrl;
        begin
            bus_sel = 4'd0; alu_op = 3'd0;
            alu_b_sel = 0; h_src_sel = 0; mdr_src_sel = 0; flags_src_sel = 0;
            pc_load = 0; pc_inc = 0; ir_load = 0; a_load = 0; h_load = 0;
            r0_load = 0; r1_load = 0; mar_load = 0; mdr_load = 0;
            flags_load = 0; pc_save_load = 0; flags_save_load = 0;
            data_bus_oe = 0; tb_drive_bus = 0; tb_data_out = 8'h00;
        end
    endtask

    initial begin
        $dumpfile("tb_datapath.vcd");
        $dumpvars(0, tb_datapath);

        clk = 0; rst = 1; irq_vector = 8'h70;
        clear_ctrl();
        @(posedge clk); #1;
        rst = 0;

        // 1. Read 0xFF from external data_bus into MDR, then move MDR -> A and R0
        tb_drive_bus = 1; tb_data_out = 8'hFF;
        mdr_src_sel = 1; mdr_load = 1;
        @(posedge clk); #1; clear_ctrl();

        bus_sel = 4'd5; // BUS_MDR
        a_load = 1; r0_load = 1;
        @(posedge clk); #1; clear_ctrl();

        // 2. Execute MUL: {H, A} <= A * R0 (0xFF * 0xFF = 0xFE01)
        alu_op = 3'b010; // OP_MUL
        alu_b_sel = 0;   // R0
        bus_sel = 4'd6;  // BUS_ALU_LO
        a_load = 1;
        h_src_sel = 1; h_load = 1;
        flags_src_sel = 0; flags_load = 1;
        @(posedge clk); #1; clear_ctrl();

        // 3. Drive H (0xFE) out onto external data_bus via MDR
        bus_sel = 4'd1; // BUS_H
        mdr_src_sel = 0; mdr_load = 1;
        @(posedge clk); #1; clear_ctrl();

        data_bus_oe = 1;
        #2;
        if (data_bus === 8'hFE && flags_out === 4'b0110)
            $display("PASS [MUL & BUS WRITE]: H=0x%h on data_bus, FLAGS=%b", data_bus, flags_out);
        else
            $display("FAIL [MUL & BUS WRITE]: Got data_bus=0x%h, FLAGS=%b", data_bus, flags_out);
        @(posedge clk); #1; clear_ctrl();

        // 4. Test PC increment, IRQ Save, Jump to Vector 0x70, and Restore
        pc_inc = 1; @(posedge clk); #1; // PC = 0x01
        pc_inc = 1; @(posedge clk); #1; clear_ctrl(); // PC = 0x02

        // Save PC & FLAGS, load IRQ vector
        pc_save_load = 1; flags_save_load = 1;
        bus_sel = 4'd9; pc_load = 1; // PC <= 0x70
        @(posedge clk); #1; clear_ctrl();

        // Load MAR from PC to observe PC on addr_bus
        bus_sel = 4'd4; mar_load = 1;
        @(posedge clk); #1; clear_ctrl();
        if (addr_bus === 8'h70)
            $display("PASS [IRQ VECTOR]: PC jumped to 0x%h", addr_bus);
        else
            $display("FAIL [IRQ VECTOR]: Expected 0x70, got 0x%h", addr_bus);

        // Restore PC from PC_SAVE
        bus_sel = 4'd8; pc_load = 1;
        @(posedge clk); #1; clear_ctrl();
        bus_sel = 4'd4; mar_load = 1;
        @(posedge clk); #1; clear_ctrl();
        if (addr_bus === 8'h02)
            $display("PASS [RETI RESTORE]: PC restored to 0x%h", addr_bus);
        else
            $display("FAIL [RETI RESTORE]: Expected 0x02, got 0x%h", addr_bus);

        $display("\nDATAPATH VERIFICATION COMPLETE.");
        $finish;
    end
endmodule
