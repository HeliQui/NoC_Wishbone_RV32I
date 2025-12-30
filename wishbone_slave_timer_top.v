module wishbone_slave (
    input clk_i,
    input rst_i,

    // Wishbone Bus Interface
    input      [31:0] addr_i,
    output     [31:0] data_o,  // Dữ liệu ghi ra Slave
    input      [31:0] data_i,  // Dữ liệu đọc từ Slave
    input             we_i,
    input             stb_i,
    input             cyc_i,
    input      [ 3:0] sel_i,
    output reg        ack_o,

    output reg [1:0] state,  // Current state
    output [31:0] debug_timer_val
);


  // Define state machine
  localparam IDLE = 2'b00;
  localparam BUSY = 2'b01;
  localparam BUSY_next = 2'b10;

  reg [1:0] next_state;

  // 1. Khối chuyển trạng thái (Sequential)
  always @(posedge clk_i) begin
    if (rst_i) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // 2. Khối tính toán trạng thái kế tiếp (Combinational)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (stb_i && cyc_i) next_state = BUSY;
      end
      BUSY: begin
        next_state = BUSY_next;  //  author: lnq - chuyển qua trạng thái busy tiếp theo 
      end
      BUSY_next: begin  // author: lnq
        next_state = IDLE;  // author: lnq
      end  // author: lnq
      default: next_state = IDLE;
    endcase
  end

  // Giúp stb_o và cyc_o xuất hiện ngay khi chuyển sang BUSY
  always @(*) begin
    //    ack_o = 1'b0;
    ack_o = (state == BUSY);
    case (state)
      //      BUSY_next: begin
      BUSY: begin
        ack_o = 1'b1;
      end
      BUSY_next: begin
        ack_o = 1'b0;
      end
    endcase
  end

  /*
always @(*) begin
        case (state)
            BUSY:    ack_o = 1'b1;
            default: ack_o = 1'b0; // Gọn gàng và an toàn tuyệt đối
        endcase
    end
    */

  // --- Kết nối với Timer Core (Thay cho dmem) ---
  // Chỉ ghi khi ở trạng thái BUSY và lệnh là Write
  wire timer_we = (state == BUSY) && we_i;
  wire [31:0] timer_data_out;
  timer my_timer (
      .clk        (clk_i),
      .rst        (rst_i),
      .we         (timer_we),
      .addr       (addr_i[3:2]),     // Lấy bit 3:2 để phân biệt 4 word
      .din        (data_i),          // Dữ liệu từ Master truyền vào
      .dout       (timer_data_out),  // Dữ liệu từ Timer trả về Master
      .current_val(debug_timer_val)
  );
  assign data_o = timer_data_out;

endmodule
