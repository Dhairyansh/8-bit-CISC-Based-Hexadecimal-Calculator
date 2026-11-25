`timescale 1ns / 1ps

module tb_alu;
    reg  [7:0] a, b;
    reg  [2:0] alu_op;
    wire [7:0] result_lo, result_hi;
    wire [3:0] flags; // {V, N, C, Z}

    // Instantiate Unit Under Test (UUT)
    alu uut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result_lo(result_lo),
        .result_hi(result_hi),
        .flags(flags)
    );

    integer errors = 0;

    task check_alu;
        input [7:0] exp_hi;
        input [7:0] exp_lo;
        input [3:0] exp_flags;
        input [127:0] test_name;
        begin
            #10;
            if (result_hi !== exp_hi || result_lo !== exp_lo || flags !== exp_flags) begin
                $display("FAIL [%0s]: A=%h B=%h OP=%b | Got: HI=%h LO=%h FLAGS=%b | Exp: HI=%h LO=%h FLAGS=%b",
                         test_name, a, b, alu_op, result_hi, result_lo, flags, exp_hi, exp_lo, exp_flags);
                errors = errors + 1;
            end else begin
                $display("PASS [%0s]: A=%h B=%h OP=%b -> HI=%h LO=%h FLAGS=%b",
                         test_name, a, b, alu_op, result_hi, result_lo, flags);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        // 1. ADD Tests
        a = 8'h12; b = 8'h34; alu_op = 3'b000; check_alu(8'h00, 8'h46, 4'b0000, "ADD_BASIC");
        a = 8'h7F; b = 8'h01; alu_op = 3'b000; check_alu(8'h00, 8'h80, 4'b1100, "ADD_OVF");
        a = 8'hFF; b = 8'h01; alu_op = 3'b000; check_alu(8'h00, 8'h00, 4'b0011, "ADD_CARRY_Z");

        // 2. SUB Tests
        a = 8'h50; b = 8'h20; alu_op = 3'b001; check_alu(8'h00, 8'h30, 4'b0000, "SUB_BASIC");
        a = 8'h05; b = 8'h0A; alu_op = 3'b001; check_alu(8'h00, 8'hFB, 4'b0110, "SUB_NEG_BRW");
        a = 8'h2A; b = 8'h2A; alu_op = 3'b001; check_alu(8'h00, 8'h00, 4'b0001, "SUB_ZERO");

        // 3. MUL Tests
        a = 8'h0A; b = 8'h0B; alu_op = 3'b010; check_alu(8'h00, 8'h6E, 4'b0000, "MUL_BASIC");
        a = 8'hFF; b = 8'hFF; alu_op = 3'b010; check_alu(8'hFE, 8'h01, 4'b0110, "MUL_MAX");
        a = 8'h00; b = 8'hFF; alu_op = 3'b010; check_alu(8'h00, 8'h00, 4'b0001, "MUL_ZERO");

        // 4. SHL4 & OR Tests (Hex Nibble Formation)
        a = 8'h0A; b = 8'h00; alu_op = 3'b011; check_alu(8'h00, 8'hA0, 4'b0100, "SHL4_NIBBLE");
        a = 8'hA0; b = 8'h05; alu_op = 3'b100; check_alu(8'h00, 8'hA5, 4'b0100, "OR_COMBINE");

        if (errors == 0)
            $display("\nALL ALU TESTS PASSED!");
        else
            $display("\nALU TESTS FAILED WITH %0d ERRORS.", errors);

        $finish;
    end
endmodule
