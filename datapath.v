
// ============================================================================
// Module: datapath.v
// Description: Complete 8-bit CISC Processor Datapath
//              Integrates PC, IR, A, H, R0, R1, MAR, MDR, FLAGS, PC_SAVE,
//              FLAGS_SAVE, ALU, 8-bit Internal MUX Bus, and Bidirectional
//              External Data Bus Interface.
// ============================================================================

module datapath (
    input  wire       clk,
    input  wire       rst,

    // Control signals from Control Unit FSM
    input  wire [3:0] bus_sel,         // Selects source driving int_bus
    input  wire [2:0] alu_op,          // ALU operation select
    input  wire       alu_b_sel,       // 0: R0, 1: MDR
    input  wire       h_src_sel,       // 0: int_bus, 1: alu_hi
    input  wire       mdr_src_sel,     // 0: int_bus, 1: external data_bus
    input  wire       flags_src_sel,   // 0: alu_flags, 1: flags_save

    // Register load / control enables
    input  wire       pc_load,
    input  wire       pc_inc,
    input  wire       ir_load,
    input  wire       a_load,
    input  wire       h_load,
    input  wire       r0_load,
    input  wire       r1_load,
    input  wire       mar_load,
    input  wire       mdr_load,
    input  wire       flags_load,
    input  wire       pc_save_load,
    input  wire       flags_save_load,

    // External bidirectional data bus output enable
    input  wire       data_bus_oe,     // 1: drive MDR onto data_bus; 0: High-Z

    // Interrupt vector input from Interrupt Controller
    input  wire [7:0] irq_vector,

    // Status outputs to Control Unit
    output wire [7:0] ir_out,          // Current opcode for Instruction Decoder
    output wire [3:0] flags_out,       // {V, N, C, Z} for conditional branches

    // External Memory / I/O Bus
    output wire [7:0] addr_bus,        // Driven by MAR
    inout  wire [7:0] data_bus         // Bidirectional 8-bit external data bus
);

    // ------------------------------------------------------------------------
    // Internal Bus Source Encodings (bus_sel)
    // ------------------------------------------------------------------------
    localparam [3:0] BUS_A       = 4'd0;
    localparam [3:0] BUS_H       = 4'd1;
    localparam [3:0] BUS_R0      = 4'd2;
    localparam [3:0] BUS_R1      = 4'd3;
    localparam [3:0] BUS_PC      = 4'd4;
    localparam [3:0] BUS_MDR     = 4'd5;
    localparam [3:0] BUS_ALU_LO  = 4'd6;
    localparam [3:0] BUS_ALU_HI  = 4'd7;
    localparam [3:0] BUS_PC_SAVE = 4'd8;
    localparam [3:0] BUS_IRQ_VEC = 4'd9;

    // Internal wires
    reg  [7:0] int_bus;
    wire [7:0] pc_out;
    wire [7:0] a_out, h_out, r0_out, r1_out;
    wire [7:0] mar_out, mdr_out;
    wire [7:0] pc_save_out;
    wire [3:0] flags_save_out;

    wire [7:0] alu_b_in;
    wire [7:0] alu_lo, alu_hi;
    wire [3:0] alu_flags;

    wire [7:0] h_in;
    wire [7:0] mdr_in;
    wire [3:0] flags_in;

    // ------------------------------------------------------------------------
    // Internal 8-bit MUX Bus
    // ------------------------------------------------------------------------
    always @(*) begin
        case (bus_sel)
            BUS_A:       int_bus = a_out;
            BUS_H:       int_bus = h_out;
            BUS_R0:      int_bus = r0_out;
            BUS_R1:      int_bus = r1_out;
            BUS_PC:      int_bus = pc_out;
            BUS_MDR:     int_bus = mdr_out;
            BUS_ALU_LO:  int_bus = alu_lo;
            BUS_ALU_HI:  int_bus = alu_hi;
            BUS_PC_SAVE: int_bus = pc_save_out;
            BUS_IRQ_VEC: int_bus = irq_vector;
            default:     int_bus = 8'h00;
        endcase
    end

    // ------------------------------------------------------------------------
    // Input Multiplexers for ALU, H, MDR, and FLAGS
    // ------------------------------------------------------------------------
    assign alu_b_in = alu_b_sel     ? mdr_out        : r0_out;
    assign h_in     = h_src_sel     ? alu_hi         : int_bus;
    assign mdr_in   = mdr_src_sel   ? data_bus       : int_bus;
    assign flags_in = flags_src_sel ? flags_save_out : alu_flags;

    // ------------------------------------------------------------------------
    // External Bus Assignments
    // ------------------------------------------------------------------------
    assign addr_bus = mar_out;
    assign data_bus = data_bus_oe ? mdr_out : 8'hZZ;

    // ------------------------------------------------------------------------
    // Core Register Instantiations
    // ------------------------------------------------------------------------
    pc u_pc (
        .clk     (clk),
        .rst     (rst),
        .pc_load (pc_load),
        .pc_inc  (pc_inc),
        .pc_in   (int_bus),
        .pc_out  (pc_out)
    );

    reg8 u_ir (
        .clk  (clk),
        .rst  (rst),
        .load (ir_load),
        .d    (int_bus),
        .q    (ir_out)
    );

    reg8 u_acc (
        .clk  (clk),
        .rst  (rst),
        .load (a_load),
        .d    (int_bus),
        .q    (a_out)
    );

    reg8 u_h (
        .clk  (clk),
        .rst  (rst),
        .load (h_load),
        .d    (h_in),
        .q    (h_out)
    );

    reg8 u_r0 (
        .clk  (clk),
        .rst  (rst),
        .load (r0_load),
        .d    (int_bus),
        .q    (r0_out)
    );

    reg8 u_r1 (
        .clk  (clk),
        .rst  (rst),
        .load (r1_load),
        .d    (int_bus),
        .q    (r1_out)
    );

    reg8 u_mar (
        .clk  (clk),
        .rst  (rst),
        .load (mar_load),
        .d    (int_bus),
        .q    (mar_out)
    );

    reg8 u_mdr (
        .clk  (clk),
        .rst  (rst),
        .load (mdr_load),
        .d    (mdr_in),
        .q    (mdr_out)
    );

    // Interrupt Shadow Registers
    reg8 u_pc_save (
        .clk  (clk),
        .rst  (rst),
        .load (pc_save_load),
        .d    (pc_out),
        .q    (pc_save_out)
    );

    flags_reg u_flags (
        .clk       (clk),
        .rst       (rst),
        .load      (flags_load),
        .flags_in  (flags_in),
        .flags_out (flags_out)
    );

    flags_reg u_flags_save (
        .clk       (clk),
        .rst       (rst),
        .load      (flags_save_load),
        .flags_in  (flags_out),
        .flags_out (flags_save_out)
    );

    // ------------------------------------------------------------------------
    // ALU Instantiation
    // ------------------------------------------------------------------------
    alu u_alu (
        .a         (a_out),
        .b         (alu_b_in),
        .alu_op    (alu_op),
        .result_lo (alu_lo),
        .result_hi (alu_hi),
        .flags     (alu_flags)
    );

endmodule