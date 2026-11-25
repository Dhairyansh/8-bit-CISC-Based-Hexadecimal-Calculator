// ============================================================================
// Module: cpu_top.v
// Description: Top-Level 8-bit CISC Microprocessor Core
// ============================================================================

module cpu_top (
    input  wire       clk,
    input  wire       rst,
    input  wire       irq_key,    // INT0
    input  wire       irq_clr,    // INT1
    output wire [7:0] addr_bus,
    inout  wire [7:0] data_bus,
    output wire       mem_rd,
    output wire       mem_wr,
    output wire       io_rd,
    output wire       io_wr
);

    wire [3:0] bus_sel;
    wire [2:0] alu_op;
    wire       alu_b_sel, h_src_sel, mdr_src_sel, flags_src_sel;
    wire       pc_load, pc_inc, ir_load, a_load, h_load, r0_load, r1_load;
    wire       mar_load, mdr_load, flags_load, pc_save_load, flags_save_load;
    wire       data_bus_oe;
    wire [7:0] ir_out;
    wire [3:0] flags_out;

    wire       ie_set, ie_clr, irq_pending;
    wire [7:0] irq_vector;

    interrupt_ctrl u_irq (
        .clk         (clk),
        .rst         (rst),
        .irq_key     (irq_key),
        .irq_clr     (irq_clr),
        .ie_set      (ie_set),
        .ie_clr      (ie_clr),
        .irq_pending (irq_pending),
        .irq_vector  (irq_vector)
    );

    control_unit u_ctrl (
        .clk             (clk),
        .rst             (rst),
        .ir_out          (ir_out),
        .flags_out       (flags_out),
        .irq_pending     (irq_pending),
        .bus_sel         (bus_sel),
        .alu_op          (alu_op),
        .alu_b_sel       (alu_b_sel),
        .h_src_sel       (h_src_sel),
        .mdr_src_sel     (mdr_src_sel),
        .flags_src_sel   (flags_src_sel),
        .pc_load         (pc_load),
        .pc_inc          (pc_inc),
        .ir_load         (ir_load),
        .a_load          (a_load),
        .h_load          (h_load),
        .r0_load         (r0_load),
        .r1_load         (r1_load),
        .mar_load        (mar_load),
        .mdr_load        (mdr_load),
        .flags_load      (flags_load),
        .pc_save_load    (pc_save_load),
        .flags_save_load (flags_save_load),
        .data_bus_oe     (data_bus_oe),
        .mem_rd          (mem_rd),
        .mem_wr          (mem_wr),
        .io_rd           (io_rd),
        .io_wr           (io_wr),
        .ie_set          (ie_set),
        .ie_clr          (ie_clr)
    );

    datapath u_dp (
        .clk             (clk),
        .rst             (rst),
        .bus_sel         (bus_sel),
        .alu_op          (alu_op),
        .alu_b_sel       (alu_b_sel),
        .h_src_sel       (h_src_sel),
        .mdr_src_sel     (mdr_src_sel),
        .flags_src_sel   (flags_src_sel),
        .pc_load         (pc_load),
        .pc_inc          (pc_inc),
        .ir_load         (ir_load),
        .a_load          (a_load),
        .h_load          (h_load),
        .r0_load         (r0_load),
        .r1_load         (r1_load),
        .mar_load        (mar_load),
        .mdr_load        (mdr_load),
        .flags_load      (flags_load),
        .pc_save_load    (pc_save_load),
        .flags_save_load (flags_save_load),
        .data_bus_oe     (data_bus_oe),
        .irq_vector      (irq_vector),
        .ir_out          (ir_out),
        .flags_out       (flags_out),
        .addr_bus        (addr_bus),
        .data_bus        (data_bus)
    );

endmodule
