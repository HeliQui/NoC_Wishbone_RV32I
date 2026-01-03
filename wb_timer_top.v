//////////////////////////////////////////////////////////////////////////////////
// Design Name: wb_led_matrix_top
// Description: Top level wrapper ket noi Wishbone Slave Interface va led 
//////////////////////////////////////////////////////////////////////////////////
module wb_timer_top (

    input wire clk_i,
    input wire rst,

    // --- Wishbone Interface (External Ports) ---
    // Tin hieu tu Master gui den (Ten chuan ngan gon: adr, dat)
    input wire [31:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    input wire [ 3:0] wb_sel_i,
    input wire        wb_we_i,
    input wire        wb_cyc_i,
    input wire        wb_stb_i,

    // Tin hieu tra ve cho Master
    output wire [31:0] wb_dat_o,
    output wire        wb_ack_o,

    // LED PINS
    output wire [31:0] timer_value
);

  // --- Day noi noi bo (Internal Wires) ---
  // Cac tin hieu nay ket noi giua Interface va RAM Core
  wire [31:0] timer_addr;
  wire [31:0] timer_wdata;
  wire [31:0] timer_rdata;  // Du lieu doc tu LED tra ve Interface
  wire        timer_we;

  // 1. Interface (Adapter): Quan ly FSM va Handshake Wishbone
  wishbone_slave_adapter_timer wb_slave_adapter (
      .clk_i  (clk_i),
      .rst(rst),

      // --- Wishbone Side (Mapping Port Adapter -> Port Top) ---
      .wb_addr_i(wb_adr_i),
      .wb_data_i(wb_dat_i),
      .wb_data_o(wb_dat_o),
      .wb_we_i  (wb_we_i),
      .wb_stb_i (wb_stb_i),
      .wb_cyc_i (wb_cyc_i),
      .wb_sel_i (wb_sel_i),
      .wb_ack_o (wb_ack_o),

      // --- Memory Side (Mapping Port Adapter -> Internal Wires) ---
      // Luu y: Ten port phai khop voi definition cua wishbone_slave_adapter
      .timer_addr_o (timer_addr),   // Adapter output -> Wire
      .timer_wdata_o(timer_wdata),  // Adapter output -> Wire
      .timer_rdata_i(timer_rdata),  // Wire -> Adapter input
      .timer_we_o   (timer_we)
  );

  // 2. TIMER
  timer timer_inst (
      .clk(clk_i),
      .rst(rst),
      // --- Input tu Interface (Noi vao day noi bo) ---
      .addr (timer_addr[3:2]), // Lay bit 3:2 de phan biet 4 word
      .din(timer_wdata),
      .we   (timer_we),

      // --- Output tra ve Interface ---
      .dout(timer_rdata),
      .current_val(timer_value)
  );

endmodule
