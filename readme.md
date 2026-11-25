# 8-Bit CISC Hexadecimal Calculator (EE224 Digital Systems)

A synthesizable 8-bit Complex Instruction Set Computer (CISC) hexadecimal calculator implemented in Verilog HDL (`calc_top`), complete with a multi-cycle control unit, arithmetic/logic unit with 16-bit multiplication, unified 256-byte memory and memory-mapped I/O space, debounced 4x4 matrix keypad and function buttons, multiplexed 4-digit common-cathode 7-segment display controller, and Questa verification testbenches.

---

## Architecture Overview

The system integrates a multi-cycle processor core (`cpu_top`) with combinational address decoding (`addr_decoder`), external memory models (`flash_rom` and `sram`), and peripheral controllers (`keypad_if` and `display_ctrl`) over an 8-bit address bus (`addr_bus[7:0]`), a bidirectional external data bus (`data_bus[7:0]`), and explicit memory/I/O read and write strobes (`mem_rd`, `mem_wr`, `io_rd`, `io_wr`).

### Top-Level System (`calc_top`)
```text
+---------------------------------------------------------------------------------+
|                                   calc_top                                      |
|                                                                                 |
|  +--------------------+     addr_bus[7:0]     +----------------------------+    |
|  |      cpu_top       |======================>|           addr_decoder     |    |
|  | - control_unit     | mem_rd, mem_wr,       |        0x00-0x7F -> cs_rom |    |
|  | - datapath         | io_rd, io_wr          |        0x80-0xDF -> cs_ram |    |
|  | - interrupt_ctrl   |======================>|        0xE0-0xFF -> cs_io  |    |
|  +--------------------+                       +-------------------------=--+    |
|     ^        ^        |                        |         |       |       |      |
|     |        |        | data_bus[7:0] (inout)  |  cs_rom | cs_ram|  cs_io|      |
|  irq_key  irq_clr     +------+------+------+---+         v       v       v      |
|     |        |               |      |      |       +---------+ +-----+ +----+   |
|  +--+--------+-------+       v      v      v       |flash_rom| |sram | | I/O|   |
|  |     keypad_if     |     +------------------+    | 128 B   | |96 B | |Mux |   |
|  | - scan & debounce |<===>| Tri-State Bus    |    +---------+ +-----+ +----+   |
|  | - port 0xE0 latch |     | (8'hZZ inactive) |                       |         |
|  +-------------------+     +------------------+                       v         |
|    ^          ^                                                 +------------+  |
|    |          |                                                 |display_ctrl|  |
| keypad_col/  btn_add/sub/                                       |0xE1-0xE3   |  |
| keypad_row   mul/eq/clr                                         |seg, dig_en |  | 
+-----------------------------------------------------------------+------------+--+ 
                                                                   |     |      |
                                                                   v     v      v
                                                              4-Digit Common-Cathode
                                                              7-Segment Display
```

### Internal Processor Core (`cpu_top`)
```text
+-------------------------------------------------------------------------+
|                                cpu_top                                  |
|                                                                         |
|  +------+  +-----+  +------+  +------+  +------+                        |
|  |  PC  |  |  A  |  |  R0  |  |  R1  |  |  H   |   (IR, MAR, MDR)       |
|  +--+---+  +--+--+  +---+--+  +---+--+  +---+--+                        |
|     |         |         |         |         |                           |
|     +---------+----+----+---------+---------+                           |
|                    v                                                    |
|           +-----------------+                                           |
|           | Internal Bus /  |---> addr_bus[7:0]                         |
|           |   Mux Network   |<==> data_bus[7:0] (to tri-state I/O)      |
|           +--------+--------+                                           |
|                    |                                                    |
|                    v                                                    |
|           +-----------------+                                           |
|           |       ALU       |---> flags[3:0] (Z, N, C, V)               |
|           | ADD, SUB, MUL8x8|               |                           |
|           +-----------------+               |                           |
|                    ^                        |                           |
|                    | control signals        | flags, irq_key, irq_clr   |
|                    |                        v                           |
|           +---------------------------------------------------+         |
|           | control_unit (FSM) + interrupt_ctrl               |         |
|           | FETCH1 -> FETCH2 -> DECODE -> EXEC -> INT_CHECK   |         |
|           | -> IRQ_ENTRY (0x70 / 0x78) -> RETI                |         |
|           +---------------------------------------------------+         |
+-------------------------------------------------------------------------+
```

---

## Unified Memory and I/O Map

| Address Range | Size | Module | Access & Function |
| :--- | :--- | :--- | :--- |
| `0x00` – `0x7F` | 128 B | `flash_rom` | Read-only program ROM (`cs_rom & mem_rd`); vectors at `0x70` (`IRQ_KEY`) and `0x78` (`IRQ_CLR`) |
| `0x80` – `0xDF` | 96 B | `sram` | Read/write data RAM (`cs_ram & mem_rd/wr` synchronous on `posedge clk`) |
| `0xE0` | 1 B | `keypad_if` | Read (`cs_io & io_rd`, `port_sel=2'b00`): returns latched key code and clears `irq_key` |
| `0xE1` | 1 B | `display_ctrl` | Write (`cs_io & io_wr`, `port_sel=2'b01`): updates `disp_lo[7:0]` |
| `0xE2` | 1 B | `display_ctrl` | Write (`cs_io & io_wr`, `port_sel=2'b10`): updates `disp_hi[7:0]` |
| `0xE3` | 1 B | `display_ctrl` | Write (`cs_io & io_wr`, `port_sel=2'b11`): updates `disp_ctrl[0]` (negative sign flag) |
| `0xE4` – `0xFF` | 28 B | Reserved I/O | Decoded under `cs_io` for future peripheral expansion |

---

## Key Features & Subsystems

* **CISC Instruction Set:** Supports 1-byte and 2-byte instructions including `NOP`, `MOV`, `LDI A, #imm8`, `LOAD A, [addr8]`, `STORE A, [addr8]`, `ADD`, `SUB`, `MUL R0` ($8 \times 8 \rightarrow 16$-bit product across `{H, A}`), conditional/unconditional branches (`JMP`, `JZ`, `JN`), interrupt control (`EI`, `RETI`), and I/O transfers (`IN`, `OUT`).
* **Status Flags:** Tracks Zero (`Z`), Negative (`N`), Carry (`C`), and Overflow (`V`) flags in the ALU/datapath.
* **Dual Vectored Interrupts:** `IRQ_KEY` (`INT0` $\rightarrow$ vector `0x70`) for keypad and operation/equals inputs; `IRQ_CLR` (`INT1` $\rightarrow$ vector `0x78`) for clearing display state.
* **Keypad Interface (`keypad_if.v`):** Cycles active-high row scan lines (`keypad_row[3:0]`), samples column lines (`keypad_col[3:0]`) and function buttons (`btn_add`, `btn_sub`, `btn_mul`, `btn_eq`, `btn_clr`), and applies synchronous debouncing (`DEBOUNCE_MAX`).
* **7-Segment Display Controller (`display_ctrl.v`):** Drives active-high segments (`seg[6:0] = {g,f,e,d,c,b,a}`) and active-low digit enables (`dig_en[3:0]`) with time-multiplexing (`MUX_DIV_MAX`) and negative-sign display support (`disp_ctrl[0]`).

---

## Running Verification in Questa

1. Compile the design and testbench files:
   ```tcl
   vlog keypad_if.v calc_top.v tb_system.v
   ```
2. Load the testbench with visibility enabled and add the four curated signal groups:
   ```tcl
   vsim -voptargs="+acc" work.tb_system
   delete wave *
   add wave -group "Bus_and_Strobes" sim:/tb_system/clk sim:/tb_system/rst sim:/tb_system/addr_bus sim:/tb_system/data_bus sim:/tb_system/mem_rd sim:/tb_system/mem_wr sim:/tb_system/io_rd sim:/tb_system/io_wr
   add wave -group "Interrupts_and_Input" sim:/tb_system/uut/irq_key sim:/tb_system/uut/irq_clr sim:/tb_system/keypad_row sim:/tb_system/keypad_col sim:/tb_system/btn_add sim:/tb_system/btn_sub sim:/tb_system/btn_mul sim:/tb_system/btn_clr
   add wave -group "Display_Regs" sim:/tb_system/uut/u_display/disp_hi sim:/tb_system/uut/u_display/disp_lo sim:/tb_system/uut/u_display/disp_ctrl
   add wave -group "7Seg_Outputs" sim:/tb_system/dig_en sim:/tb_system/seg
   run -all
   ```

### Verified System Test Cases (`tb_system.v`)

| Test ID | Operation / Event | Actual | Expected | Status |
| :--- | :--- | :--- | :--- | :--- |
| `TC01_ADD` | `0x1A + 0x26` | `0x0040 (n=0)` | `0x0040 (n=0)` | PASS |
| `TC02_ADD_WRAP` | `0xFF + 0x01` | `0x0000 (n=0)` | `0x0000 (n=0)` | PASS |
| `TC03_SUB` | `0x55 - 0x20` | `0x0035 (n=0)` | `0x0035 (n=0)` | PASS |
| `TC04_NEG_SUB` | `0x05 - 0x0A` | `0x00FB (n=1)` | `0x00FB (n=1)` | PASS |
| `TC05_ZERO_SUB` | `0x42 - 0x42` | `0x0000 (n=0)` | `0x0000 (n=0)` | PASS |
| `TC06_MUL_MID` | `0x12 * 0x0A` | `0x00B4 (n=0)` | `0x00B4 (n=0)` | PASS |
| `TC07_MUL_MAX` | `0xFF * 0xFF` | `0xFE01 (n=0)` | `0xFE01 (n=0)` | PASS |
| `TC08_MUL_ZERO` | `0x00 * 0xAB` | `0x0000 (n=0)` | `0x0000 (n=0)` | PASS |
| `TC09_KEY_HEX_F` | Matrix key `'F'` IRQ | `0x000F (n=0)` | `0x000F (n=0)` | PASS |
| `TC10_CLR_IRQ` | `IRQ_CLR` reset | `0x0000 (n=0)` | `0x0000 (n=0)` | PASS |

---

## Hardware Synthesis Notes

* **Timing Scaling:** Simulation testbenches use small `DEBOUNCE_MAX` and `MUX_DIV_MAX` values for fast runtimes. For a $50\text{ MHz}$ FPGA clock, scale `DEBOUNCE_MAX` to $\sim 10\text{--}20\text{ ms}$ ($500{,}000\text{--}1{,}000{,}000$ cycles) and `MUX_DIV_MAX` to $\sim 1\text{--}2\text{ ms}$ per digit ($\sim 50{,}000$ cycles).
* **ROM Initialization:** Replace testbench hierarchical array assignments (`uut.u_rom.rom[...]`) with a `.hex` or `.mif` initialization image loaded into `flash_rom` before FPGA synthesis.
