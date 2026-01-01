//////////////////////////////////////////////////////////////////////////////////
// Design Name: wb_led_matrix_top
// Description: Top level wrapper ket noi Wishbone Slave Interface va led 
//////////////////////////////////////////////////////////////////////////////////
module wb_led_matrix_top (

    input wire clk_i,
    input wire rst_n_i,

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
    output wire [31:0] led_pins
);

  // --- Day noi noi bo (Internal Wires) ---
  // Cac tin hieu nay ket noi giua Interface va RAM Core
  wire [31:0] led_addr;
  wire [31:0] led_wdata;
  wire [31:0] led_rdata;  // Du lieu doc tu LED tra ve Interface
  wire        led_we;

  // 1. Interface (Adapter): Quan ly FSM va Handshake Wishbone
  wishbone_slave_adapter_led_matrix wb_slave_adapter (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),

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
      .led_addr_o (led_addr),   // Adapter output -> Wire
      .led_wdata_o(led_wdata),  // Adapter output -> Wire
      .led_rdata_i(led_rdata),  // Wire -> Adapter input
      .led_we_o   (led_we)
  );

  // 2. LED MATRIX
  led_matrix led_matrix_inst (
      .clk(clk_i),
      .rst_n(rst_n_i),
      // --- Input tu Interface (Noi vao day noi bo) ---
      .addr_i (led_addr[3:2]), // 2'b00: CTRL, 2'b01: DATA
      .write_data(led_wdata),
      .write_en   (led_we),

      // --- Output tra ve Interface ---
      .read_data(led_rdata),
      .led_pins (led_pins)
  );

endmodule
