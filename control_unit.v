// ============================================================================
// Module: control_unit.v
// Description: Hardwired Multi-Cycle FSM Control Unit & Instruction Decoder
// ============================================================================

module control_unit (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] ir_out,
    input  wire [3:0] flags_out,       // {V, N, C, Z}
    input  wire       irq_pending,

    // Datapath Control Outputs
    output reg  [3:0] bus_sel,
    output reg  [2:0] alu_op,
    output reg        alu_b_sel,
    output reg        h_src_sel,
    output reg        mdr_src_sel,
    output reg        flags_src_sel,
    output reg        pc_load,
    output reg        pc_inc,
    output reg        ir_load,
    output reg        a_load,
    output reg        h_load,
    output reg        r0_load,
    output reg        r1_load,
    output reg        mar_load,
    output reg        mdr_load,
    output reg        flags_load,
    output reg        pc_save_load,
    output reg        flags_save_load,
    output reg        data_bus_oe,

    // External Memory / IO Control Outputs
    output reg        mem_rd,
    output reg        mem_wr,
    output reg        io_rd,
    output reg        io_wr,

    // Interrupt Controller Signals
    output reg        ie_set,
    output reg        ie_clr
);

    // ------------------------------------------------------------------------
    // Opcodes (Matching Stage 1 ISA Specification)
    // ------------------------------------------------------------------------
    localparam [7:0] OP_NOP      = 8'h00;
    localparam [7:0] OP_LDI      = 8'h10;
    localparam [7:0] OP_LOAD     = 8'h11;
    localparam [7:0] OP_STORE    = 8'h12;
    localparam [7:0] OP_MOV_R0_A = 8'h20;
    localparam [7:0] OP_MOV_A_R0 = 8'h21;
    localparam [7:0] OP_MOV_R1_A = 8'h22;
    localparam [7:0] OP_MOV_A_H  = 8'h23;
    localparam [7:0] OP_ADD_R0   = 8'h30;
    localparam [7:0] OP_ADD_MEM  = 8'h31;
    localparam [7:0] OP_SUB_R0   = 8'h40;
    localparam [7:0] OP_SUB_MEM  = 8'h41;
    localparam [7:0] OP_MUL_R0   = 8'h50;
    localparam [7:0] OP_MUL_MEM  = 8'h51;
    localparam [7:0] OP_SHL4     = 8'h60;
    localparam [7:0] OP_OR_R0    = 8'h61;
    localparam [7:0] OP_JMP      = 8'h70;
    localparam [7:0] OP_JZ       = 8'h71;
    localparam [7:0] OP_JNZ      = 8'h72;
    localparam [7:0] OP_JN       = 8'h73;
    localparam [7:0] OP_IN       = 8'h80;
    localparam [7:0] OP_OUT      = 8'h81;
    localparam [7:0] OP_EI       = 8'h90;
    localparam [7:0] OP_DI       = 8'h91;
    localparam [7:0] OP_RETI     = 8'h92;
    localparam [7:0] OP_HALT     = 8'hFF;

    // Bus Select Encodings (Matching datapath.v)
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

    // ALU Operation Encodings (Matching alu.v)
    localparam [2:0] ALU_ADD  = 3'b000;
    localparam [2:0] ALU_SUB  = 3'b001;
    localparam [2:0] ALU_MUL  = 3'b010;
    localparam [2:0] ALU_SHL4 = 3'b011;
    localparam [2:0] ALU_OR   = 3'b100;

    // FSM States
    localparam [3:0] S_FETCH1    = 4'd0;
    localparam [3:0] S_FETCH2    = 4'd1;
    localparam [3:0] S_FETCH3    = 4'd2;
    localparam [3:0] S_DECODE    = 4'd3;
    localparam [3:0] S_OP_FETCH1 = 4'd4;
    localparam [3:0] S_OP_FETCH2 = 4'd5;
    localparam [3:0] S_EXEC_2B   = 4'd6;
    localparam [3:0] S_MEM_RD    = 4'd7;
    localparam [3:0] S_MEM_EXEC  = 4'd8;
    localparam [3:0] S_MEM_WR1   = 4'd9;
    localparam [3:0] S_MEM_WR2   = 4'd10;
    localparam [3:0] S_IO_RD     = 4'd11;
    localparam [3:0] S_IO_RD_WB  = 4'd12;
    localparam [3:0] S_IO_WR1    = 4'd13;
    localparam [3:0] S_IO_WR2    = 4'd14;
    localparam [3:0] S_INT_CHECK = 4'd15;

    // Extended states using 5-bit state register
    reg [4:0] state, next_state;
    localparam [4:0] S_IRQ_ENTRY = 5'd16;
    localparam [4:0] S_HALT      = 5'd17;

    wire flag_z = flags_out[0];
    wire flag_n = flags_out[2];

    // State Register
    always @(posedge clk) begin
        if (rst)
            state <= {1'b0, S_FETCH1};
        else
            state <= next_state;
    end

    // Next-State and Output Logic
    always @(*) begin
        // Default control outputs (all inactive)
        bus_sel         = BUS_A;
        alu_op          = ALU_ADD;
        alu_b_sel       = 1'b0;
        h_src_sel       = 1'b0;
        mdr_src_sel     = 1'b0;
        flags_src_sel   = 1'b0;
        pc_load         = 1'b0;
        pc_inc          = 1'b0;
        ir_load         = 1'b0;
        a_load          = 1'b0;
        h_load          = 1'b0;
        r0_load         = 1'b0;
        r1_load         = 1'b0;
        mar_load        = 1'b0;
        mdr_load        = 1'b0;
        flags_load      = 1'b0;
        pc_save_load    = 1'b0;
        flags_save_load = 1'b0;
        data_bus_oe     = 1'b0;
        mem_rd          = 1'b0;
        mem_wr          = 1'b0;
        io_rd           = 1'b0;
        io_wr           = 1'b0;
        ie_set          = 1'b0;
        ie_clr          = 1'b0;

        next_state = {1'b0, S_FETCH1};

        case (state)
            // ---------------- INSTRUCTION FETCH ----------------
            {1'b0, S_FETCH1}: begin
                bus_sel    = BUS_PC;
                mar_load   = 1'b1;
                pc_inc     = 1'b1;
                next_state = {1'b0, S_FETCH2};
            end

            {1'b0, S_FETCH2}: begin
                mem_rd      = 1'b1;
                mdr_src_sel = 1'b1;
                mdr_load    = 1'b1;
                next_state  = {1'b0, S_FETCH3};
            end

            {1'b0, S_FETCH3}: begin
                bus_sel    = BUS_MDR;
                ir_load    = 1'b1;
                next_state = {1'b0, S_DECODE};
            end

            // ---------------- DECODE & 1-BYTE EXEC ----------------
            {1'b0, S_DECODE}: begin
                case (ir_out)
                    OP_NOP: next_state = {1'b0, S_INT_CHECK};

                    OP_MOV_R0_A: begin
                        bus_sel = BUS_A; r0_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_MOV_A_R0: begin
                        bus_sel = BUS_R0; a_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_MOV_R1_A: begin
                        bus_sel = BUS_A; r1_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_MOV_A_H: begin
                        bus_sel = BUS_H; a_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end

                    OP_ADD_R0: begin
                        alu_op = ALU_ADD; alu_b_sel = 1'b0;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        h_src_sel = 1'b1; h_load = 1'b1;
                        flags_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_SUB_R0: begin
                        alu_op = ALU_SUB; alu_b_sel = 1'b0;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        h_src_sel = 1'b1; h_load = 1'b1;
                        flags_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_MUL_R0: begin
                        alu_op = ALU_MUL; alu_b_sel = 1'b0;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        h_src_sel = 1'b1; h_load = 1'b1;
                        flags_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_SHL4: begin
                        alu_op = ALU_SHL4;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        flags_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_OR_R0: begin
                        alu_op = ALU_OR; alu_b_sel = 1'b0;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        flags_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end

                    OP_EI: begin
                        ie_set = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_DI: begin
                        ie_clr = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_RETI: begin
                        bus_sel = BUS_PC_SAVE; pc_load = 1'b1;
                        flags_src_sel = 1'b1; flags_load = 1'b1;
                        ie_set = 1'b1;
                         next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_HALT: next_state = S_HALT;

                    // 2-Byte Instructions -> Fetch Operand Byte
                    OP_LDI, OP_LOAD, OP_STORE,
                    OP_ADD_MEM, OP_SUB_MEM, OP_MUL_MEM,
                    OP_JMP, OP_JZ, OP_JNZ, OP_JN,
                    OP_IN, OP_OUT: begin
                        next_state = {1'b0, S_OP_FETCH1};
                    end

                    // Invalid Opcode -> Treat as NOP safely
                    default: next_state = {1'b0, S_INT_CHECK};
                endcase
            end

            // ---------------- OPERAND BYTE FETCH ----------------
            {1'b0, S_OP_FETCH1}: begin
                bus_sel    = BUS_PC;
                mar_load   = 1'b1;
                pc_inc     = 1'b1;
                next_state = {1'b0, S_OP_FETCH2};
            end

            {1'b0, S_OP_FETCH2}: begin
                mem_rd      = 1'b1;
                mdr_src_sel = 1'b1;
                mdr_load    = 1'b1;
                next_state  = {1'b0, S_EXEC_2B};
            end

            // ---------------- 2-BYTE EXECUTION ----------------
            {1'b0, S_EXEC_2B}: begin
                case (ir_out)
                    OP_LDI: begin
                        bus_sel = BUS_MDR; a_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_JMP: begin
                        bus_sel = BUS_MDR; pc_load = 1'b1;
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_JZ: begin
                        if (flag_z) begin bus_sel = BUS_MDR; pc_load = 1'b1; end
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_JNZ: begin
                        if (!flag_z) begin bus_sel = BUS_MDR; pc_load = 1'b1; end
                        next_state = {1'b0, S_INT_CHECK};
                    end
                    OP_JN: begin
                        if (flag_n) begin bus_sel = BUS_MDR; pc_load = 1'b1; end
                        next_state = {1'b0, S_INT_CHECK};
                    end

                    OP_LOAD, OP_ADD_MEM, OP_SUB_MEM, OP_MUL_MEM: begin
                        bus_sel = BUS_MDR; mar_load = 1'b1;
                        next_state = {1'b0, S_MEM_RD};
                    end
                    OP_STORE: begin
                        bus_sel = BUS_MDR; mar_load = 1'b1;
                        next_state = {1'b0, S_MEM_WR1};
                    end
                    OP_IN: begin
                        bus_sel = BUS_MDR; mar_load = 1'b1;
                        next_state = {1'b0, S_IO_RD};
                    end
                    OP_OUT: begin
                        bus_sel = BUS_MDR; mar_load = 1'b1;
                        next_state = {1'b0, S_IO_WR1};
                    end
                    default: next_state = {1'b0, S_INT_CHECK};
                endcase
            end

            // ---------------- MEMORY READ & EXEC ----------------
            {1'b0, S_MEM_RD}: begin
                mem_rd      = 1'b1;
                mdr_src_sel = 1'b1;
                mdr_load    = 1'b1;
                next_state  = {1'b0, S_MEM_EXEC};
            end

            {1'b0, S_MEM_EXEC}: begin
                case (ir_out)
                    OP_LOAD: begin
                        bus_sel = BUS_MDR; a_load = 1'b1;
                    end
                    OP_ADD_MEM: begin
                        alu_op = ALU_ADD; alu_b_sel = 1'b1;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        h_src_sel = 1'b1; h_load = 1'b1;
                        flags_load = 1'b1;
                    end
                    OP_SUB_MEM: begin
                        alu_op = ALU_SUB; alu_b_sel = 1'b1;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        h_src_sel = 1'b1; h_load = 1'b1;
                        flags_load = 1'b1;
                    end
                    OP_MUL_MEM: begin
                        alu_op = ALU_MUL; alu_b_sel = 1'b1;
                        bus_sel = BUS_ALU_LO; a_load = 1'b1;
                        h_src_sel = 1'b1; h_load = 1'b1;
                        flags_load = 1'b1;
                    end
                    default: ;
                endcase
                next_state = {1'b0, S_INT_CHECK};
            end

            // ---------------- MEMORY WRITE ----------------
            {1'b0, S_MEM_WR1}: begin
                bus_sel     = BUS_A;
                mdr_src_sel = 1'b0;
                mdr_load    = 1'b1;
                next_state  = {1'b0, S_MEM_WR2};
            end

            {1'b0, S_MEM_WR2}: begin
                data_bus_oe = 1'b1;
                mem_wr      = 1'b1;
                next_state  = {1'b0, S_INT_CHECK};
            end

            // ---------------- I/O READ & WRITE ----------------
            {1'b0, S_IO_RD}: begin
                io_rd       = 1'b1;
                mdr_src_sel = 1'b1;
                mdr_load    = 1'b1;
                next_state  = {1'b0, S_IO_RD_WB};
            end

            {1'b0, S_IO_RD_WB}: begin
                bus_sel    = BUS_MDR;
                a_load     = 1'b1;
                next_state = {1'b0, S_INT_CHECK};
            end

            {1'b0, S_IO_WR1}: begin
                bus_sel     = BUS_A;
                mdr_src_sel = 1'b0;
                mdr_load    = 1'b1;
                next_state  = {1'b0, S_IO_WR2};
            end

            {1'b0, S_IO_WR2}: begin
                data_bus_oe = 1'b1;
                io_wr       = 1'b1;
                next_state  = {1'b0, S_INT_CHECK};
            end

            // ---------------- INTERRUPT HANDLING ----------------
            {1'b0, S_INT_CHECK}: begin
                if (irq_pending)
                    next_state = S_IRQ_ENTRY;
                else
                    next_state = {1'b0, S_FETCH1};
            end

            S_IRQ_ENTRY: begin
                pc_save_load    = 1'b1;
                flags_save_load = 1'b1;
                bus_sel         = BUS_IRQ_VEC;
                pc_load         = 1'b1;
                ie_clr          = 1'b1;
                next_state      = {1'b0, S_FETCH1};
            end

            S_HALT: begin
                if (irq_pending)
                    next_state = S_IRQ_ENTRY;
                else
                    next_state = S_HALT;
            end

            default: next_state = {1'b0, S_FETCH1};
        endcase
    end

endmodule
