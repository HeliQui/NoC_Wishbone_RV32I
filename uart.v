`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87

module uart (
    input  wire        clk,
    input  wire        rst_n,
    // Giao tiếp với Wishbone Adapter (giống module LED/Timer của bạn)
    input  wire [ 1:0] addr_i,      // Lấy từ led_addr[3:2] như đã thảo luận
    input  wire [31:0] write_data,
    input  wire        write_en,
    input  wire        i_uart_sel,
    output reg  [31:0] read_data,

    // Chân vật lý ra bên ngoài
    output wire uart_tx,
    input  wire uart_rx
);

  // Tín hiệu trung gian kết nối với module bạn sưu tầm
  wire       tx_active;
  wire       tx_done;
  wire       rx_dv;
  wire [7:0] rx_byte;
  reg        tx_dv;

    localparam clk_per_bit = 4; // for testing 

  // 1. Module Transmitter (từ source của bạn)
  uart_transmitter #(
      .CLKS_PER_BIT(clk_per_bit) 
  ) uart_tx_inst (
      .i_Clock(clk),
      .i_Tx_DV(tx_dv),
      .i_Tx_Byte(write_data[7:0]),
      .o_Tx_Active(tx_active),
      .o_Tx_Serial(uart_tx),
      .o_Tx_Done(tx_done)
  );

  // 2. Module Receiver (từ source của bạn)
  uart_receiver #(
      .CLKS_PER_BIT(clk_per_bit) 
  ) uart_rx_inst (
      .i_Clock(clk),
      .i_Rx_Serial(uart_rx),
      .o_Rx_DV(rx_dv),
      .o_Rx_Byte(rx_byte)
  );

  reg r_rx_data_ready;  // Biến giữ trạng thái để CPU đọc

  // 3. Logic điều khiển (Giao tiếp với RISC-V)
  always @(posedge clk) begin
    if (!rst_n) begin
      tx_dv <= 1'b0;
      r_rx_data_ready <= 1'b0;
    end else begin
      // --- Logic cho Transmitter ---
      if (i_uart_sel && write_en && (addr_i == 2'b00)) tx_dv <= 1'b1;
      else tx_dv <= 1'b0;

      // --- Logic cho Receiver ---
      if (rx_dv) begin
        r_rx_data_ready <= 1'b1;
      end 
      // CHỈ XÓA KHI: Có lệnh truy cập THẬT (i_uart_sel) và là lệnh ĐỌC (!write_en)
      else if (i_uart_sel && !write_en && (addr_i == 2'b00)) begin
        // Khi CPU thực hiện lệnh ĐỌC vào địa chỉ Data (2'b00)
        // Ta hiểu là CPU đã lấy hàng xong -> Hạ cờ xuống
        r_rx_data_ready <= 1'b0;
      end
    end
  end
  // 4. Logic Đọc (CPU kiểm tra trạng thái)
  always @(*) begin
    case (addr_i)
      2'b00:   read_data = {24'h0, rx_byte};
      // Trả về r_rx_data_ready (đã được giữ) thay vì rx_dv (xung ngắn)
      2'b01:   read_data = {30'h0, r_rx_data_ready, tx_active};
      default: read_data = 32'h0;
    endcase
  end

endmodule
