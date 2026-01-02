module wishbone_slave_adapter_uart (
    input clk_i,
    input rst_n_i,

    // --- Giao diện Wishbone ---
    input  [31:0] wb_addr_i,
    input  [31:0] wb_data_i,
    output [31:0] wb_data_o,
    input         wb_we_i,
    input         wb_stb_i,
    input         wb_cyc_i,
    input  [ 3:0] wb_sel_i,
    output        wb_ack_o,

    // --- Giao diện nối vào UART_TEMP
    output [ 1:0] uart_addr_o,   // Dia chi 2-bit (00: Data, 01: Status)
    output [31:0] uart_wdata_o,
    input  [31:0] uart_rdata_i,
    output        uart_we_o,     // Write Enable cho UART
    output        uart_sel_o     // Tin hieu bao hieu UART duoc chon (de xoa co Ready)
);

  // --- 1. Dinh nghia FSM (Giong het Timer Adapter cua ban) ---
  localparam STATE_IDLE = 2'b00;
  localparam STATE_ACK = 2'b01;
  localparam STATE_COOLDOWN = 2'b10;

  reg [1:0] state, next_state;

  always @(posedge clk_i) begin
    if (~rst_n_i) state <= STATE_IDLE;
    else state <= next_state;
  end

  always @(*) begin
    next_state = state;
    case (state)
      STATE_IDLE: begin
        if (wb_stb_i && wb_cyc_i) next_state = STATE_ACK;
      end
      STATE_ACK: begin
        next_state = STATE_COOLDOWN;
      end
      STATE_COOLDOWN: begin
        next_state = STATE_IDLE;
      end
      default: next_state = STATE_IDLE;
    endcase
  end

  // --- 2. Logic xuat tin hieu phia Wishbone ---
  assign wb_ack_o  = (state == STATE_ACK);
  assign wb_data_o = uart_rdata_i;

  // --- 3. Logic ket noi phia UART_TEMP ---
  // Lay bit [3:2] de phan biet word (0x0, 0x4)
  assign uart_addr_o  = wb_addr_i[3:2];
  assign uart_wdata_o = wb_data_i;

  // Quan trong: Chi bat Write Enable khi Master thuc su yeu cau ghi va dang o chu ky hop le
  assign uart_we_o    = wb_stb_i && wb_cyc_i && wb_we_i;

  // Tin hieu nay bao cho UART biet CPU dang thuc su doc/ghi vao no
  assign uart_sel_o   = wb_stb_i && wb_cyc_i;

endmodule
