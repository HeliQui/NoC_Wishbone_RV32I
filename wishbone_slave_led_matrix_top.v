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
    output [31:0] debug_led_out
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

  // --- Kết nối với LED Matrix Core ---
  wire led_we = (state == BUSY) && we_i;
  wire [31:0] led_data_out;

  led_matrix my_led_matrix (
      .clk       (clk_i),
      .rst       (rst_i),
      .write_en  (led_we),
      .addr_i    (addr_i[3:2]),   // 2'b00: CTRL, 2'b01: DATA
      .write_data(data_i),        // Dữ liệu ghi từ Master
      .read_data (led_data_out),  // Dữ liệu đọc trả về Master
      .led_pins  (debug_led_out)  // Chân nối ra LED thực tế
  );

  assign data_o = led_data_out;
endmodule
