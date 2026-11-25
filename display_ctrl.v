
// ============================================================================
// Module: display_ctrl.v
// Description: Common-Cathode 4-Digit Seven-Segment Display Controller
//              Memory-mapped write ports (cs_io && io_wr):
//                port_sel == 2'b01 (0xE1): disp_lo[7:0]
//                port_sel == 2'b10 (0xE2): disp_hi[7:0]
//                port_sel == 2'b11 (0xE3): disp_ctrl[7:0] (bit 0 = negative sign)
//              Segments seg[6:0] = {g,f,e,d,c,b,a} are ACTIVE-HIGH (common cathode).
//              Digit enables dig_en[3:0] are ACTIVE-LOW.
// ============================================================================

module display_ctrl #(
    parameter integer MUX_DIV_MAX = 2   // Set small (e.g., 2) for fast sim; scale for flicker-free LED
)(
    input  wire       clk,
    input  wire       rst,

    // I/O Bus Interface (Ports 0xE1 - 0xE3)
    input  wire       cs_io,
    input  wire       io_wr,
    input  wire [1:0] port_sel,       // addr_bus[1:0]
    input  wire [7:0] data_in,        // Latched from external data_bus

    // Common-Cathode 7-Segment Outputs
    output reg  [6:0] seg,            // Active-high: {g,f,e,d,c,b,a}
    output reg  [3:0] dig_en          // Active-low:  3=leftmost, 0=rightmost
);

    reg [7:0] disp_lo;
    reg [7:0] disp_hi;
    reg [7:0] disp_ctrl; // bit 0: 1 => negative signed result

    always @(posedge clk) begin
        if (rst) begin
            disp_lo   <= 8'h00;
            disp_hi   <= 8'h00;
            disp_ctrl <= 8'h00;
        end else if (cs_io && io_wr) begin
            case (port_sel)
                2'b01: disp_lo   <= data_in;
                2'b10: disp_hi   <= data_in;
                2'b11: disp_ctrl <= data_in;
                default: ;
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // Signed / Magnitude Formatting for 4 Hex Digits (Digit 3..0)
    // ------------------------------------------------------------------------
    wire is_negative = disp_ctrl[0];
    // For negative 8-bit values in disp_lo, compute magnitude; high byte 0x00
    wire [7:0] mag_lo = is_negative ? (~disp_lo + 8'h01) : disp_lo;
    wire [7:0] mag_hi = is_negative ? 8'h00              : disp_hi;

    // Nibbles to display on digits 3 (left), 2, 1, 0 (right)
    wire [3:0] nib3 = mag_hi[7:4];
    wire [3:0] nib2 = mag_hi[3:0];
    wire [3:0] nib1 = mag_lo[7:4];
    wire [3:0] nib0 = mag_lo[3:0];

    // ------------------------------------------------------------------------
    // Digit Multiplexing Counter
    // ------------------------------------------------------------------------
    reg [15:0] div_cnt;
    reg [1:0]  active_dig;

    always @(posedge clk) begin
        if (rst) begin
            div_cnt    <= 16'd0;
            active_dig <= 2'd0;
        end else if (div_cnt < MUX_DIV_MAX) begin
            div_cnt    <= div_cnt + 16'd1;
        end else begin
            div_cnt    <= 16'd0;
            active_dig <= active_dig + 2'd1;
        end
    end

    // Select active nibble & active-low digit enable
    reg [3:0] cur_nibble;
    reg       show_minus;

    always @(*) begin
        dig_en     = 4'b1111;
        cur_nibble = 4'h0;
        show_minus = 1'b0;

        case (active_dig)
            2'd3: begin
                dig_en     = 4'b0111; // Digit 3 active (low)
                cur_nibble = nib3;
                if (is_negative)
                    show_minus = 1'b1;
            end
            2'd2: begin
                dig_en     = 4'b1011; // Digit 2 active (low)
                cur_nibble = nib2;
            end
            2'd1: begin
                dig_en     = 4'b1101; // Digit 1 active (low)
                cur_nibble = nib1;
            end
            2'd0: begin
                dig_en     = 4'b1110; // Digit 0 active (low)
                cur_nibble = nib0;
            end
        endcase
    end

    // ------------------------------------------------------------------------
    // Hexadecimal-to-Seven-Segment Decoder (Active-High {g,f,e,d,c,b,a})
    // ------------------------------------------------------------------------
    reg [6:0] hex_seg;

    always @(*) begin
        case (cur_nibble)
            4'h0: hex_seg = 7'b011_1111; // 0
            4'h1: hex_seg = 7'b000_0110; // 1
            4'h2: hex_seg = 7'b101_1011; // 2
            4'h3: hex_seg = 7'b100_1111; // 3
            4'h4: hex_seg = 7'b110_0110; // 4
            4'h5: hex_seg = 7'b110_1101; // 5
            4'h6: hex_seg = 7'b111_1101; // 6
            4'h7: hex_seg = 7'b000_0111; // 7
            4'h8: hex_seg = 7'b111_1111; // 8
            4'h9: hex_seg = 7'b110_1111; // 9
            4'hA: hex_seg = 7'b111_0111; // A
            4'hB: hex_seg = 7'b111_1100; // b
            4'hC: hex_seg = 7'b011_1001; // C
            4'hD: hex_seg = 7'b101_1110; // d
            4'hE: hex_seg = 7'b111_1001; // E
            4'hF: hex_seg = 7'b111_0001; // F
            default: hex_seg = 7'b000_0000;
        endcase
    end

    always @(*) begin
        if (show_minus)
            seg = 7'b100_0000; // '-' (segment g only)
        else
            seg = hex_seg;
    end

endmodule