module gpio_basic (
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  addr,
    input  wire        we,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    inout  wire [31:0] gpio_pins
);

    // --- 1. Internal Registers ---
    reg [31:0] reg_dir;
    reg [31:0] reg_out;
    reg [31:0] reg_in;

    // --- 2. Tri-state Logic (KHÔNG DÙNG GENERATE) ---
    // T?o m?t bi?n reg trung gian ?? tính toán logic
    reg [31:0] driver_val; 
    integer k; // Bi?n ch?y vòng l?p

    // Dùng always @(*) ?? mô t? m?ch t? h?p (Combinational logic)
    always @(*) begin
        for (k = 0; k < 32; k = k + 1) begin
            // Logic vi?t y h?t nh? l?p trình C
            if (reg_dir[k] == 1'b1) begin
                driver_val[k] = reg_out[k]; // N?u là Output -> l?y giá tr? reg_out
            end else begin
                driver_val[k] = 1'bz;       // N?u là Input  -> ng?t (High-Z)
            end
        end
    end

    // Cu?i cùng: N?i bi?n trung gian ra dây v?t lý
    assign gpio_pins = driver_val;


    // --- 3. Input Synchronization (Gi? nguyên) ---
    always @(posedge clk or negedge rst) begin
        if (~rst) reg_in <= 32'd0;
        else     reg_in <= gpio_pins;
    end

    // --- 4. Write Logic (Gi? nguyên) ---
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            reg_dir <= 32'd0;
            reg_out <= 32'd0;
        end else if (we) begin
            case (addr)
                2'b00: reg_dir <= wdata;
                2'b01: reg_out <= wdata;
            endcase
        end
    end

    // --- 5. Read Logic (Gi? nguyên) ---
    always @(*) begin
        case (addr)
            2'b00: rdata = reg_dir;
            2'b01: rdata = reg_out;
            2'b10: rdata = reg_in;
            default: rdata = 32'd0;
        endcase
    end

endmodule