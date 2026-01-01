module timer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,          // Write Enable từ wrapper
    input  wire [ 1:0] addr,        // Địa chỉ rút gọn (0, 1, 2)
    input  wire [31:0] din,         // Dữ liệu ghi vào
    output reg  [31:0] dout,        // Dữ liệu đọc ra
    output      [31:0] current_val  // Để debug
);
  reg [31:0] ctrl;
  reg [31:0] period;
  reg [31:0] value;

  assign current_val = value;

  // Logic Đọc (Combinational)
  always @(*) begin
    case (addr)
      2'b00:   dout = ctrl;
      2'b01:   dout = period;
      2'b10:   dout = value;
      default: dout = 32'h0;
    endcase
  end

  // Logic Ghi & Đếm (Sequential)
  always @(posedge clk) begin
    if (~rst_n) begin
      ctrl   <= 32'h0;
      period <= 32'hFFFF_FFFF;
      value  <= 32'h0;
    end else begin
      // 1. Xử lý ghi từ Bus
      if (we) begin
        if (addr == 2'b00) ctrl <= din;
        if (addr == 2'b01) period <= din;
      end

      // 2. Logic đếm của Timer
      if (ctrl[1]) begin  // Bit Reset counter
        value <= 32'h0;
      end else if (ctrl[0]) begin  // Bit Enable
        if (value >= period) value <= 32'h0;
        else value <= value + 1;
      end
    end
  end
endmodule
