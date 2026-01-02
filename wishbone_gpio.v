module wishbone_gpio (
    input wire clk_i,
    input wire rst_n_i,

    // --- Wishbone Interface ---
    input  wire [31:0] wb_addr_i,
    input  wire [31:0] wb_data_i,
    input  wire        wb_we_i,
    input  wire        wb_stb_i,
    input  wire        wb_cyc_i,
    output wire [31:0] wb_data_o,
    output wire        wb_ack_o,

    // --- External Pins ---
    inout  wire [31:0] gpio_pins
);

    // --- 1. Internal Signals & Constants ---
    // ??nh ngh?a 3 tr?ng thái
    localparam STATE_IDLE     = 2'b00;
    localparam STATE_ACK      = 2'b01;
    localparam STATE_COOLDOWN = 2'b10; // Tr?ng thái ngh? an toàn

    reg [1:0] state, next_state; // T?ng lên 2 bit ?? ch?a 3 tr?ng thái
    
    // Tín hi?u ?i?u khi?n cho Core
    wire [1:0] core_addr;
    wire       core_we;
    wire [31:0] core_rdata;

    // --- 2. Instantiate GPIO Core ---
    gpio_basic core (
        .clk      (clk_i),
        .rst      (rst_n_i),    // ??o bit ?? ?úng chu?n Active High Reset c?a core
        .addr     (core_addr),
        .we       (core_we),
        .wdata    (wb_data_i),
        .rdata    (core_rdata),
        .gpio_pins(gpio_pins)
    );

    // --- 3. Address Mapping ---
    // Mapping: 0x00->0, 0x04->1, 0x08->2
    assign core_addr = wb_addr_i[3:2]; 

    // --- 4. FSM Logic (3 State - Safe Mode) ---
    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) state <= STATE_IDLE;
        else          state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                // N?u có yêu c?u h?p l? -> Chuy?n sang ACK
                if (wb_cyc_i && wb_stb_i) 
                    next_state = STATE_ACK;
            end
            STATE_ACK: begin
                // ?ã ACK xong -> Sang COOLDOWN (ngh? 1 nh?p)
                // ?? ??m b?o Master k?p h? STB xu?ng
                next_state = STATE_COOLDOWN;
            end
            STATE_COOLDOWN: begin
                // H?t th?i gian ngh? -> Quay v? IDLE s?n sàng ?ón request m?i
                next_state = STATE_IDLE;
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    // --- 5. Output Logic ---
    // Ch? b?t ACK khi ?ang ? tr?ng thái STATE_ACK
    assign wb_ack_o  = (state == STATE_ACK);
    
    // D? li?u luôn ???c ??a ra bus
    assign wb_data_o = core_rdata;

    // QUAN TR?NG: Ch? cho phép ghi vào Core khi b?t ??u phát hi?n request (? IDLE)
    // Khi sang ACK hay COOLDOWN thì core_we ph?i b?ng 0 ngay.
    assign core_we = (wb_cyc_i && wb_stb_i && wb_we_i) && (state == STATE_IDLE);

endmodule