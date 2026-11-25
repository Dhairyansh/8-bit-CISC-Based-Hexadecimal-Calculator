
// ============================================================================
// Module: alu.v
// Description: 8-bit Combinational ALU for Custom CISC Microprocessor
//              Supports ADD, SUB, MUL (16-bit output), SHL4, OR, and PASS ops.
//              Generates 4 status flags: {V, N, C, Z}.
// ============================================================================

module alu (
    input  wire [7:0] a,          // Operand A (typically Accumulator)
    input  wire [7:0] b,          // Operand B (typically R0 or MDR)
    input  wire [2:0] alu_op,     // Operation select from Control Unit
    output reg  [7:0] result_lo,  // Lower 8 bits of result (goes to A)
    output reg  [7:0] result_hi,  // Upper 8 bits of result (goes to H on MUL)
    output wire [3:0] flags       // Status flags: [3]=V, [2]=N, [1]=C, [0]=Z
);

    // ALU Operation Encodings
    localparam [2:0] OP_ADD    = 3'b000;
    localparam [2:0] OP_SUB    = 3'b001;
    localparam [2:0] OP_MUL    = 3'b010;
    localparam [2:0] OP_SHL4   = 3'b011;
    localparam [2:0] OP_OR     = 3'b100;
    localparam [2:0] OP_PASS_A = 3'b101;
    localparam [2:0] OP_PASS_B = 3'b110;

    // Internal wires/regs for intermediate calculations
    reg [8:0]  add_res;
    reg [8:0]  sub_res;
    reg [15:0] mul_res;

    reg flag_z; // Zero flag
    reg flag_c; // Carry (ADD) / Borrow (SUB) / High-byte non-zero (MUL)
    reg flag_n; // Negative flag (MSB of result)
    reg flag_v; // Signed overflow flag

    assign flags = {flag_v, flag_n, flag_c, flag_z};

    always @(*) begin
        // Default assignments to prevent inferred latches
        result_lo = 8'h00;
        result_hi = 8'h00;
        add_res   = 9'h000;
        sub_res   = 9'h000;
        mul_res   = 16'h0000;
        flag_z    = 1'b0;
        flag_c    = 1'b0;
        flag_n    = 1'b0;
        flag_v    = 1'b0;

        case (alu_op)
            OP_ADD: begin
                add_res   = {1'b0, a} + {1'b0, b};
                result_lo = add_res[7:0];
                result_hi = 8'h00;
                flag_c    = add_res[8];
                flag_z    = (result_lo == 8'h00);
                flag_n    = result_lo[7];
                flag_v    = (a[7] == b[7]) && (result_lo[7] != a[7]);
            end

            OP_SUB: begin
                sub_res   = {1'b0, a} - {1'b0, b};
                result_lo = sub_res[7:0];
                result_hi = 8'h00;
                flag_c    = sub_res[8]; // 1 indicates borrow (a < b unsigned)
                flag_z    = (result_lo == 8'h00);
                flag_n    = result_lo[7];
                flag_v    = (a[7] != b[7]) && (result_lo[7] != a[7]);
            end

            OP_MUL: begin
                mul_res   = a * b; // Synthesizes to 8x8 unsigned array multiplier
                result_lo = mul_res[7:0];
                result_hi = mul_res[15:8];
                flag_c    = (mul_res[15:8] != 8'h00); // Result exceeds 8 bits
                flag_z    = (mul_res == 16'h0000);
                flag_n    = mul_res[15];
                flag_v    = 1'b0;
            end

            OP_SHL4: begin
                result_lo = {a[3:0], 4'b0000};
                result_hi = 8'h00;
                flag_z    = (result_lo == 8'h00);
                flag_n    = result_lo[7];
            end

            OP_OR: begin
                result_lo = a | b;
                result_hi = 8'h00;
                flag_z    = (result_lo == 8'h00);
                flag_n    = result_lo[7];
            end

            OP_PASS_A: begin
                result_lo = a;
                result_hi = 8'h00;
                flag_z    = (result_lo == 8'h00);
                flag_n    = result_lo[7];
            end

            OP_PASS_B: begin
                result_lo = b;
                result_hi = 8'h00;
                flag_z    = (result_lo == 8'h00);
                flag_n    = result_lo[7];
            end

            default: begin
                result_lo = 8'h00;
                result_hi = 8'h00;
            end
        endcase
    end

endmodule