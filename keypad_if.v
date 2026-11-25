// ============================================================================
// Module: keypad_if.v
// Description: 4x4 Hexadecimal Keypad Scanner, Debouncer, and I/O Interface
//              Generates irq_key (INT0) on valid hex/op/eq key press, cleared
//              when CPU reads I/O port 0xE0 (cs_io && io_rd && addr[1:0]==00).
//              Also debounces btn_clr to generate irq_clr (INT1), cleared on
//              I/O read of 0xE0/0xE1 or I/O write to 0xE1.
// ============================================================================

module keypad_if #(
    parameter integer DEBOUNCE_MAX = 4   // Set small (e.g., 4) for fast sim; scale for board
)(
    input  wire       clk,
    input  wire       rst,

    // I/O Bus Interface (Ports 0xE0 - 0xE3)
    input  wire       cs_io,
    input  wire       io_rd,
    input  wire       io_wr,
    input  wire [1:0] port_sel,       // addr_bus[1:0]
    inout  wire [7:0] data_bus,

    // Matrix Keypad & Function Buttons
    input  wire [3:0] keypad_col,     // Active-high column inputs (pulled down externally)
    output reg  [3:0] keypad_row,     // Active-high row scan outputs (1-hot)
    input  wire       btn_add,        // '+' key
    input  wire       btn_sub,        // '-' key
    input  wire       btn_mul,        // 'x' key
    input  wire       btn_eq,         // '=' key
    input  wire       btn_clr,        // 'CLR' key

    // Interrupt Requests
    output reg        irq_key,        // INT0: key available in buffer
    output reg        irq_clr         // INT1: clear requested
);

    // ------------------------------------------------------------------------
    // Row Scanner (Cycles 0 -> 1 -> 2 -> 3 every clock)
    // ------------------------------------------------------------------------
    reg [1:0] scan_row;

    always @(posedge clk) begin
        if (rst)
            scan_row <= 2'd0;
        else
            scan_row <= scan_row + 2'd1;
    end

    always @(*) begin
        case (scan_row)
            2'd0:    keypad_row = 4'b0001;
            2'd1:    keypad_row = 4'b0010;
            2'd2:    keypad_row = 4'b0100;
            2'd3:    keypad_row = 4'b1000;
            default: keypad_row = 4'b0001;
        endcase
    end

    // ------------------------------------------------------------------------
    // Raw Key Detection & Encoding
    // Matrix mapping (Row 0..3 x Col 0..3):
    //   Row 0: 0, 1, 2, 3
    //   Row 1: 4, 5, 6, 7
    //   Row 2: 8, 9, A, B
    //   Row 3: C, D, E, F
    // ------------------------------------------------------------------------
    reg       raw_valid;
    reg [7:0] raw_code;

    always @(*) begin
        raw_valid = 1'b0;
        raw_code  = 8'h00;

        if (btn_add) begin
            raw_valid = 1'b1;
            raw_code  = 8'h11; // [4]=1 (op), [3:0]=1 (ADD)
        end else if (btn_sub) begin
            raw_valid = 1'b1;
            raw_code  = 8'h12; // [4]=1 (op), [3:0]=2 (SUB)
        end else if (btn_mul) begin
            raw_valid = 1'b1;
            raw_code  = 8'h13; // [4]=1 (op), [3:0]=3 (MUL)
        end else if (btn_eq) begin
            raw_valid = 1'b1;
            raw_code  = 8'h14; // [4]=1 (op), [3:0]=4 (EQ)
        end else if (|keypad_col) begin
            raw_valid = 1'b1;
            case (keypad_col)
                4'b0001: raw_code = {3'b000, 1'b0, scan_row, 2'b00};
                4'b0010: raw_code = {3'b000, 1'b0, scan_row, 2'b01};
                4'b0100: raw_code = {3'b000, 1'b0, scan_row, 2'b10};
                4'b1000: raw_code = {3'b000, 1'b0, scan_row, 2'b11};
                default: raw_valid = 1'b0;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Debouncer for Key Press (raw_valid) -> irq_key (INT0)
    // ------------------------------------------------------------------------
    reg [15:0] db_cnt;
    reg        key_stable;
    reg        key_stable_d;
    reg [7:0]  key_latch;

    wire io_key_read = cs_io && io_rd && (port_sel == 2'b00);

    always @(posedge clk) begin
        if (rst) begin
            db_cnt       <= 16'd0;
            key_stable   <= 1'b0;
            key_stable_d <= 1'b0;
            key_latch    <= 8'h00;
            irq_key      <= 1'b0;
        end else begin
            key_stable_d <= key_stable;

            if (raw_valid) begin
                if (db_cnt < DEBOUNCE_MAX)
                    db_cnt <= db_cnt + 16'd1;
                else
                    key_stable <= 1'b1;
            end else begin
                db_cnt     <= 16'd0;
                key_stable <= 1'b0;
            end

            if (key_stable && !key_stable_d) begin
                key_latch <= raw_code;
                irq_key   <= 1'b1;
            end else if (io_key_read) begin
                irq_key   <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Debouncer for CLR Button -> irq_clr (INT1)
    // ------------------------------------------------------------------------
    reg [15:0] clr_cnt;
    reg        clr_stable;
    reg        clr_stable_d;

    wire clr_ack = io_key_read ||
                   (cs_io && io_rd && (port_sel == 2'b01)) ||
                   (cs_io && io_wr && (port_sel == 2'b01));

    always @(posedge clk) begin
        if (rst) begin
            clr_cnt      <= 16'd0;
            clr_stable   <= 1'b0;
            clr_stable_d <= 1'b0;
            irq_clr      <= 1'b0;
        end else begin
            clr_stable_d <= clr_stable;

            if (btn_clr) begin
                if (clr_cnt < DEBOUNCE_MAX)
                    clr_cnt <= clr_cnt + 16'd1;
                else
                    clr_stable <= 1'b1;
            end else begin
                clr_cnt    <= 16'd0;
                clr_stable <= 1'b0;
            end

            if (clr_stable && !clr_stable_d) begin
                irq_clr <= 1'b1;
            end else if (clr_ack) begin
                irq_clr <= 1'b0;
            end
        end
    end

    // Drive data_bus only when CPU reads keypad port 0xE0
    assign data_bus = io_key_read ? key_latch : 8'hZZ;

endmodule