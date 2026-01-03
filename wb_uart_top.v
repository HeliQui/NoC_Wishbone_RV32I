module wb_uart_top (
    input wire clk_i,
    input wire rst,

    // --- Wishbone Interface ---
    input wire [31:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    input wire [ 3:0] wb_sel_i,
    input wire        wb_we_i,
    input wire        wb_cyc_i,
    input wire        wb_stb_i,
    output wire [31:0] wb_dat_o,
    output wire        wb_ack_o,

    // --- UART PINS ---
    output wire uart_tx,
    input  wire uart_rx
);

  // --- Day noi noi bo ---
  wire [1:0]  internal_addr;
  wire [31:0] internal_wdata;
  wire [31:0] internal_rdata;
  wire        internal_we;
  wire        internal_sel;

  // 1. Interface (Adapter)
  wishbone_slave_adapter_uart adapter_inst (
      .clk_i         (clk_i),
      .rst      (rst),
      // Wishbone Side
      .wb_addr_i     (wb_adr_i),
      .wb_data_i     (wb_dat_i),
      .wb_data_o     (wb_dat_o),
      .wb_we_i       (wb_we_i),
      .wb_stb_i      (wb_stb_i),
      .wb_cyc_i      (wb_cyc_i),
      .wb_sel_i      (wb_sel_i),
      .wb_ack_o      (wb_ack_o),
      // UART Side
      .uart_addr_o   (internal_addr),
      .uart_wdata_o  (internal_wdata),
      .uart_rdata_i  (internal_rdata),
      .uart_we_o     (internal_we),
      .uart_sel_o    (internal_sel)
  );

  // 2. UART CORE (Module uart_temp chung ta da dev)
  // Luu y: Cap nhat uart_temp de nhan them tin hieu internal_sel
  uart uart_core_inst (
      .clk           (clk_i),
      .rst         (rst),
      .addr_i        (internal_addr),
      .write_data    (internal_wdata),
      .write_en      (internal_we),
      .i_uart_sel    (internal_sel), // Dung de bao ve co r_rx_data_ready
      .read_data     (internal_rdata),
      .uart_tx       (uart_tx),
      .uart_rx       (uart_rx)
  );

endmodule
