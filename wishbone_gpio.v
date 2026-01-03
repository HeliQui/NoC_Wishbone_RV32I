module wishbone_gpio (
    input wire clk_i,
    input wire rst,

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
    localparam STATE_COOLDOWN = 2'b10; 

    reg [1:0] state, next_state; 
    

    wire [1:0] core_addr;
    wire       core_we;
    wire [31:0] core_rdata;

    // --- 2. Instantiate GPIO Core ---
    gpio_basic core (
        .clk      (clk_i),
        .rst      (rst),    
        .addr     (core_addr),
        .we       (core_we),
        .wdata    (wb_data_i),
        .rdata    (core_rdata),
        .gpio_pins(gpio_pins)
    );

    // --- 3. Address Mapping ---
    // Mapping: 0x00->0, 0x04->1, 0x08->2
    assign core_addr = wb_addr_i[3:2]; 

    // --- 4. FSM Logic  ---
    always @(posedge clk_i or posedge rst) begin
        if (rst) state <= STATE_IDLE;
        else          state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (wb_cyc_i && wb_stb_i) 
                    next_state = STATE_ACK;
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

    // --- 5. Output Logic ---
    assign wb_ack_o  = (state == STATE_ACK);
    
    assign wb_data_o = core_rdata;

    assign core_we = (wb_cyc_i && wb_stb_i && wb_we_i) && (state == STATE_IDLE);

endmodule
