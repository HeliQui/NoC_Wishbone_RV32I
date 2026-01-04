module ni_ram
#(
    parameter MY_X = 1, 
    parameter MY_Y = 1,
    parameter BUFFER_DEPTH = 3 
)
(
    input clk,
    input rst_n,

    // --- Giao tiếp RAM (Wishbone Master) ---
    output reg        wb_cyc_o, wb_stb_o, wb_we_o,
    output reg [31:0] wb_adr_o, wb_dat_o,
    output reg [3:0]  wb_sel_o,      
    input             wb_ack_i,
    input      [31:0] wb_dat_i,

    // --- Giao tiếp Router ---
    output reg [0:35] channel_out, 
    input      [0:35] channel_in, 

    // --- Flow Control ---
    input      [0:1]  flow_ctrl_in, 
    output reg [0:1]  flow_ctrl_out 
);

    // =========================================================
    // 1. CREDIT MANAGEMENT (TX)
    // =========================================================
    reg [3:0] credit_count;
    reg flit_sent; 
    wire router_ready = (credit_count > 0);

    // [FIX 1]: SỬA LỖI TÍN HIỆU X (MÀU ĐỎ)
    // Dùng toán tử === để so sánh chính xác. Nếu flow_ctrl_in là X hoặc Z, kết quả sẽ là 0.
    // Điều này ngăn chặn Credit Counter bị cộng với X và biến thành X.
    wire cred_in = (flow_ctrl_in[1] === 1'b1); 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) credit_count <= BUFFER_DEPTH;
        else begin
            if (cred_in && !flit_sent && credit_count < BUFFER_DEPTH)
                credit_count <= credit_count + 1;
            else if (!cred_in && flit_sent && credit_count > 0)
                credit_count <= credit_count - 1;
        end
    end

    // =========================================================
    // 2. RX LOGIC & FSM
    // =========================================================
    wire rx_valid = channel_in[0];
    wire rx_vc    = channel_in[1]; 
    wire rx_head  = channel_in[2];
    wire rx_tail  = channel_in[3];
    wire [31:0] rx_data = channel_in[4:35];

    reg [1:0] src_x_saved, src_y_saved;
    reg [3:0] sel_saved;
    reg       we_saved; 
    reg [31:0] addr_saved;
    reg [31:0] read_data_latched; 
	 
    // Cập nhật theo chuẩn Stanford Mesh: 0:West, 1:East, 2:South, 3:North
    reg [2:0] return_lar;
    always @(*) begin
        // So sánh tọa độ Src (Core) với tọa độ RAM (MY) để biết đi hướng nào
        if (src_x_saved > MY_X)      
            return_lar = 3'd1; // East (Đi sang phải - Port 1) 
        else if (src_x_saved < MY_X) 
            return_lar = 3'd0; // West (Đi sang trái - Port 0)  
        else if (src_y_saved > MY_Y) 
            return_lar = 3'd3; // North (Đi lên - Port 3)     
        else if (src_y_saved < MY_Y) 
            return_lar = 3'd2; // South (Đi xuống - Port 2)   
        else                         
            return_lar = 3'd4; // Local
    end

    localparam S_IDLE      = 0;
    localparam S_RX_TAIL   = 1; 
    localparam S_WAIT_RAM  = 2; 
    localparam S_RESP_HEAD = 3; 
    localparam S_RESP_DATA = 4; 

    reg [2:0] state;
    reg v_valid, v_head, v_tail;
    reg [31:0] v_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            wb_cyc_o <= 0; wb_stb_o <= 0; wb_we_o <= 0;
            wb_adr_o <= 0; wb_dat_o <= 0; wb_sel_o <= 0;
            flow_ctrl_out <= 0; 
            src_x_saved <= 0; src_y_saved <= 0;
            v_valid <= 0; v_head <= 0; v_tail <= 0; v_data <= 0;
            flit_sent <= 0;
        end else begin
            flow_ctrl_out <= 0; 
            v_valid <= 0; v_head <= 0; v_tail <= 0; v_data <= 0;
            flit_sent <= 0;

            case (state)
                S_IDLE: begin
                    if (rx_valid && rx_head) begin
                        flow_ctrl_out[rx_vc] <= 1; 
                        // [24:21] Src X,Y (Lấy đúng vị trí)
                        src_x_saved <= rx_data[24:23];
                        src_y_saved <= rx_data[22:21];

                        we_saved    <= rx_data[18];
                        sel_saved   <= rx_data[17:14];
                        addr_saved  <= {18'b0, rx_data[13:0]};

                        if (rx_data[18]) begin
                            state <= S_RX_TAIL; // Write -> Chờ Data
                        end else begin
                            // Read -> Vào RAM luôn
                            wb_cyc_o <= 1; wb_stb_o <= 1; wb_we_o <= 0;
                            wb_adr_o <= {18'b0, rx_data[13:0]};
                            wb_sel_o <= rx_data[17:14];
                            state <= S_WAIT_RAM;
                        end
                    end
                end

                S_RX_TAIL: begin
                    if (rx_valid && rx_tail) begin
                         flow_ctrl_out[rx_vc] <= 1; 
                         wb_dat_o <= rx_data; 
                         wb_cyc_o <= 1; wb_stb_o <= 1; wb_we_o <= 1;
                         wb_adr_o <= addr_saved;
                         wb_sel_o <= sel_saved;
                         state <= S_WAIT_RAM;
                    end
                end

                S_WAIT_RAM: begin
                    if (wb_ack_i) begin
                        wb_cyc_o <= 0; wb_stb_o <= 0; wb_we_o <= 0;
                        wb_sel_o <= 0; 
                        if (!we_saved) read_data_latched <= wb_dat_i;
                        state <= S_RESP_HEAD;
                    end
                end

                S_RESP_HEAD: begin
                    if (router_ready) begin 
                        v_valid <= 1; v_head <= 1; 
                        
                        // --- PACKING HEADER REPLY ---
                        v_data <= {
                            return_lar,               // [31:29] Hướng về 
                            src_x_saved, src_y_saved, // [28:25] Đích (Là Src cũ)
                            MY_X[1:0], MY_Y[1:0],     // [24:21] Nguồn (Là RAM này)
                            1'b1,                     // [20]    Ack bit
                            20'b0                     // Padding
                        };
                        flit_sent <= 1; 
                        if (we_saved) begin // Write -> 1 flit
                            v_tail <= 1; state <= S_IDLE; 
                        end else begin      // Read -> 2 flit
                            v_tail <= 0; state <= S_RESP_DATA; 
                        end
                    end
                end

                S_RESP_DATA: begin
                    if (router_ready) begin
                        v_valid <= 1; v_head <= 0; v_tail <= 1;
                        v_data  <= read_data_latched;
                        flit_sent <= 1; 
                        state <= S_IDLE;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        channel_out[0]    = v_valid;
        channel_out[1]    = 1'b1; // VC 1 cho Reply
        channel_out[2]    = v_head;
        channel_out[3]    = v_tail;
        channel_out[4:35] = v_data;
    end
endmodule