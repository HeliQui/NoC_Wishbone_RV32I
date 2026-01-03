module wishbone_slave_adapter_timer (
    input clk_i,
    input rst,

    // --- Giao dien Wishbone ---
    input  [31:0] wb_addr_i,  // Dia chi tu Master
    input  [31:0] wb_data_i,  // Du lieu ghi tu Master
    output [31:0] wb_data_o,  // Du lieu doc tra ve Master
    input         wb_we_i,    // Write Enable: 1 = ghi, 0 = doc
    input         wb_stb_i,   // Strobe: bao hieu request hop le
    input         wb_cyc_i,   // Cycle: bao hieu giao dich dang dien ra
    input  [ 3:0] wb_sel_i,   // Byte select
    output        wb_ack_o,   // Acknowledge tra ve Master

    // --- Giao dien noi vao TIMER
    output [31:0] timer_addr_o,   // Dia chi gui vao TIMER
    output [31:0] timer_wdata_o,  // Du lieu ghi vao TIMER
    input  [31:0] timer_rdata_i,  // Du lieu doc tu TIMER
    output        timer_we_o      // Write Enable cho TIMER
);

  // --- 1. Dinh nghia FSM ---
  localparam STATE_IDLE = 2'b00;  // Trang thai ranh
  localparam STATE_ACK = 2'b01;  // Phat ACK = 1 trong 1 chu ky
  localparam STATE_COOLDOWN = 2'b10;  // ACK = 0, dam bao ket thuc giao dich

  reg [1:0] state, next_state;

  // --- 2. Thanh ghi trang thai ---
  always @(posedge clk_i) begin
    if (rst) state <= STATE_IDLE;
    else state <= next_state;
  end

  // --- 3. Logic chuyen trang thai ---
  always @(*) begin
    next_state = state;
    case (state)
      STATE_IDLE: begin
        // Neu thay request hop le (STB va CYC deu bang 1)
        // thi chap nhan giao dich
        if (wb_stb_i && wb_cyc_i) next_state = STATE_ACK;
      end

      STATE_ACK: begin
        // Gi? ACK trong 1 chu ky
        // Sau do chuyen sang trang thai ha ACK
        next_state = STATE_COOLDOWN;
      end

      STATE_COOLDOWN: begin
        // Tro ve IDLE de san sang nhan giao dich tiep theo
        next_state = STATE_IDLE;
      end

      default: next_state = STATE_IDLE;
    endcase
  end

  // --- 4. Logic xuat tin hieu phia Wishbone ---
  // ACK chi bat len trong trang thai STATE_ACK
  assign wb_ack_o = (state == STATE_ACK);

  // Du lieu doc tu RAM tra truc tiep ra Bus
  assign wb_data_o = timer_rdata_i;

  // --- 5. Logic ket noi phia Memory ---
  // Noi day dia chi, du lieu va byte enable
  assign timer_addr_o = wb_addr_i;
  assign timer_wdata_o = wb_data_i;


  // Write Enable: Chi ghi khi Master yeu cau ghi va chip dang duoc chon
  assign timer_we_o = wb_stb_i && wb_we_i;


endmodule
