module led_matrix (
    input wire clk,
    input wire rst,
    // Giao tiếp với Slave Wrapper
    input wire [1:0]  addr_i,    // Offset địa chỉ (ví dụ: 00, 01, 10)
    input wire [31:0] write_data,
    input wire        write_en,
    output reg [31:0] read_data,
    // Ngõ ra thực tế điều khiển phần cứng
    output wire [31:0] led_pins
);

    reg [31:0] ctrl_reg; // Thanh ghi điều khiển (ví dụ: bit 0 là độ sáng hoặc enable)
    reg [31:0] data_reg; // Thanh ghi chứa mẫu LED (bit tương ứng với đèn)

    // Logic Ghi (Write)
    always @(posedge clk) begin
        if (rst) begin
            ctrl_reg <= 32'h0;
            data_reg <= 32'h0;
        end else if (write_en) begin
            case (addr_i)
                2'b00: ctrl_reg <= write_data; // Offset 0x0
                2'b01: data_reg <= write_data; // Offset 0x4
            endcase
        end
    end

    // Logic Đọc (Read) - Để CPU kiểm tra xem đã ghi đúng chưa
    always @(*) begin
        case (addr_i)
            2'b00: read_data = ctrl_reg;
            2'b01: read_data = data_reg;
            default: read_data = 32'h0;
        endcase
    end

    // Logic xuất ra chân LED
    // Nếu bit 0 của ctrl_reg = 1 thì xuất dữ liệu, ngược lại tắt hết
    assign led_pins = ctrl_reg[0] ? data_reg : 32'h0;

endmodule
