// ============================================================================
// Module: interrupt_ctrl.v
// Description: 2-Source Priority Interrupt Controller
//              INT0 (irq_key) -> Vector 0x70 (High Priority)
//              INT1 (irq_clr) -> Vector 0x78 (Low Priority)
// ============================================================================

module interrupt_ctrl (
    input  wire       clk,
    input  wire       rst,
    input  wire       irq_key,      // INT0: Keypad Data Ready
    input  wire       irq_clr,      // INT1: User Clear/Cancel
    input  wire       ie_set,       // Asserted by EI or RETI
    input  wire       ie_clr,       // Asserted by DI or irq_ack
    output wire       irq_pending,  // High when enabled & an IRQ is active
    output reg  [7:0] irq_vector    // Vector address sent to datapath
);

    localparam [7:0] VEC_KEY = 8'h70;
    localparam [7:0] VEC_CLR = 8'h78;

    reg ie; // Global Interrupt Enable flip-flop

    always @(posedge clk) begin
        if (rst)
            ie <= 1'b0;
        else if (ie_clr)
            ie <= 1'b0;
        else if (ie_set)
            ie <= 1'b1;
    end

    assign irq_pending = ie && (irq_key || irq_clr);

    // Priority Encoder
    always @(*) begin
        if (irq_key)
            irq_vector = VEC_KEY;
        else if (irq_clr)
            irq_vector = VEC_CLR;
        else
            irq_vector = 8'h00;
    end

endmodule
