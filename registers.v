// ============================================================================
// Module: reg8
// Description: Generic 8-bit synchronous register with load enable.
// ============================================================================
module reg8 (
    input  wire       clk,
    input  wire       rst,
    input  wire       load,
    input  wire [7:0] d,
    output reg  [7:0] q
);
    always @(posedge clk) begin
        if (rst)
            q <= 8'h00;
        else if (load)
            q <= d;
    end
endmodule

// ============================================================================
// Module: pc
// Description: 8-bit Program Counter with synchronous reset, load, and increment.
// ============================================================================
module pc (
    input  wire       clk,
    input  wire       rst,
    input  wire       pc_load,   // Load new address (JMP, JZ, IRQ, RETI)
    input  wire       pc_inc,    // Increment PC by 1 (instruction fetch)
    input  wire [7:0] pc_in,
    output reg  [7:0] pc_out
);
    always @(posedge clk) begin
        if (rst)
            pc_out <= 8'h00;       // Reset vector at Flash ROM address 0x00
        else if (pc_load)
            pc_out <= pc_in;
        else if (pc_inc)
            pc_out <= pc_out + 8'h01;
    end
endmodule

// ============================================================================
// Module: flags_reg
// Description: 4-bit Status/Flag Register storing {V, N, C, Z}.
// ============================================================================
module flags_reg (
    input  wire       clk,
    input  wire       rst,
    input  wire       load,
    input  wire [3:0] flags_in,
    output reg  [3:0] flags_out
);
    always @(posedge clk) begin
        if (rst)
            flags_out <= 4'b0000;
        else if (load)
            flags_out <= flags_in;
    end
endmodule
