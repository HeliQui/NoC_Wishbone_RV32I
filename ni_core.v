module ni_core
#(
    parameter MY_X = 0,
    parameter MY_Y = 0,
    parameter BUFFER_DEPTH = 3 // Buffer_size trong parameter de 6
)
(
    input clk,
    input rst_n,

    // --- GIAO TIẾP WISHBONE SLAVE ---
    input          wb_cyc_i,    
    input          wb_stb_i,    
    input          wb_we_i,     
    input  [31:0]  wb_adr_i,    
    input  [31:0]  wb_dat_i,    
    input  [3:0]   wb_sel_i,    
    output reg     wb_ack_o,    
    output reg [31:0] wb_dat_o, 

    // --- GIAO TIẾP ROUTER ---
    output reg [0:35] channel_out, 
    input      [0:35] channel_in,

    // --- FLOW CONTROL ---
    input      [0:1]  flow_ctrl_in, 
    output reg [0:1]  flow_ctrl_out 
);

    // =========================================================================
    // 1. ROUTING LOGIC
    // =========================================================================
    reg [1:0] dest_x, dest_y;
    reg [2:0] next_port_bin; 

    // A. MAPPING
    always @(*) begin
        case(wb_adr_i[31:28]) 
            4'h0:    {dest_x, dest_y} = 4'b01_01; // RAM 1 (1,1)
            4'h1:    {dest_x, dest_y} = 4'b10_01; // led matrix (2,1)
            4'h2:    {dest_x, dest_y} = 4'b00_01; // timer (0,1)
            4'h3:    {dest_x, dest_y} = 4'b01_00; // gpio (1,0)
            4'h4:    {dest_x, dest_y} = 4'b01_10; // uarT (1,2)
            default: {dest_x, dest_y} = {MY_X[1:0], MY_Y[1:0]}; 
        endcase
    end

    // B. DIRECTION CALCULATION
    always @(*) begin
        if (dest_x > MY_X)      next_port_bin = 3'd1; // East
        else if (dest_x < MY_X) next_port_bin = 3'd0; // West
        else if (dest_y > MY_Y) next_port_bin = 3'd3; // North
        else if (dest_y < MY_Y) next_port_bin = 3'd2; // South
        else                    next_port_bin = 3'd4; // Local
    end

    // =========================================================================
    // 2. TX LOGIC & FLOW CONTROL
    // =========================================================================
    
    reg [3:0] credit_vc0; 
    reg [3:0] credit_vc1; 

    wire cred_in_vc0 = flow_ctrl_in[0]; 
    wire cred_in_vc1 = flow_ctrl_in[1];

    reg flit_valid_out; 
    wire router_ready = (credit_vc0 > 0);

    // Quản lý Credit VC0 (Request)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) credit_vc0 <= BUFFER_DEPTH;
        else begin
            case ({cred_in_vc0, flit_valid_out})
                2'b10: credit_vc0 <= credit_vc0 + 1;
                2'b01: credit_vc0 <= credit_vc0 - 1;
                default: credit_vc0 <= credit_vc0;
            endcase
        end
    end

    // Quản lý Credit VC1 (Response)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) credit_vc1 <= BUFFER_DEPTH;
        else begin
            if (cred_in_vc1) credit_vc1 <= credit_vc1 + 1;
        end
    end

    localparam S_IDLE       = 0;
    localparam S_SEND_HEAD  = 1;
    localparam S_SEND_DATA  = 2; 
    localparam S_WAIT_REPLY = 3;

    reg [2:0] state;
    reg v_head, v_tail;
    reg [31:0] v_data;
    wire wb_req = wb_cyc_i & wb_stb_i; 
    reg rx_done_ack; 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            flit_valid_out <= 0;
            v_head <= 0; v_tail <= 0; v_data <= 0;
        end else begin
            // Mặc định gán 0 để tránh latch, nhưng các case bên dưới sẽ override lại
            // flit_valid_out <= 0; 
            case (state)
                S_IDLE: begin
                    if (wb_req && !wb_ack_o && router_ready) begin
                        state <= S_SEND_HEAD;
                        flit_valid_out <= 1; 
                        v_head <= 1;
                        
                        v_data <= {
                            next_port_bin,        
                            dest_x, dest_y,       
                            MY_X[1:0], MY_Y[1:0], 
                            wb_cyc_i, wb_stb_i, wb_we_i, 
                            wb_sel_i,             
                            wb_adr_i[13:0]        
                        };

                        if (wb_we_i) v_tail <= 0; 
                        else         v_tail <= 1;
                    end else begin
                        flit_valid_out <= 0;
                    end
                end

                S_SEND_HEAD: begin
                    if (router_ready) begin
                        if (wb_we_i) begin
                            state <= S_SEND_DATA;
                            
                            // ====================================================
                            // OPTIMIZED LOOK-AHEAD CREDIT CHECK
                            // ====================================================
                            if ( (credit_vc0 >= 4'd2) || (cred_in_vc0 == 1'b1) ) begin
                                flit_valid_out <= 1; // MAX SPEED: Gửi liên tục
                            end else begin
                                flit_valid_out <= 0; // SAFE: Hết thì dừng
                            end
                            // ====================================================
                            
                            v_head <= 0; v_tail <= 1; 
                            v_data <= wb_dat_i; 
                        end else begin
                            // Lệnh Read: Chỉ có 1 flit -> Gửi xong thì nghỉ
                            state <= S_WAIT_REPLY;
                            flit_valid_out <= 0; //  Ngắt valid ngay
                        end
                    end 
                    // Nếu !router_ready: Giữ nguyên state và valid (do register lưu giá trị cũ)
                end

                S_SEND_DATA: begin
                    if (router_ready) begin
                        // Router đã nhận gói tin cuối cùng (Tail).
                        // Phải hạ Valid xuống 0 ngay lập tức để chu kỳ sau (Wait) không gửi rác.
                        flit_valid_out <= 0; 
                        state <= S_WAIT_REPLY;
                    end else begin
                        // Router bận chưa nhận -> Giữ Valid = 1 để yêu cầu gửi lại
                        flit_valid_out <= 1; 
                    end
                end

                S_WAIT_REPLY: begin
                    flit_valid_out <= 0; // Đảm bảo chắc chắn không gửi gì
                    if (rx_done_ack) begin
								state <= S_IDLE;
							end
                end
                
                default: begin
                    flit_valid_out <= 0;
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // =========================================================================
    // 3. RX LOGIC (CÓ BỘ LỌC ĐỊA CHỈ AN TOÀN)
    // =========================================================================
    wire rx_valid = channel_in[0];
    wire rx_vc    = channel_in[1];
    wire rx_head  = channel_in[2];
    wire rx_tail  = channel_in[3];
    wire [31:0] rx_payload = channel_in[4:35];
    wire rx_wb_ack_bit = rx_payload[20];

    // Lọc gói tin rac: Kiểm tra địa chỉ đích trong Header
    wire [1:0] pkt_dest_x = rx_payload[28:27];
    wire [1:0] pkt_dest_y = rx_payload[26:25];
    reg is_my_packet;

    always @(*) begin
        if (rx_valid && rx_head) begin
            if (pkt_dest_x == MY_X[1:0] && pkt_dest_y == MY_Y[1:0])
                is_my_packet = 1'b1;
            else 
                is_my_packet = 1'b0; // Gói tin ma hoặc đi lạc -> Bỏ qua
        end else begin
            is_my_packet = 1'b1; 
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wb_ack_o <= 0; wb_dat_o <= 0; flow_ctrl_out <= 0; rx_done_ack <= 0;
        end else begin
				wb_ack_o <= 0;
            flow_ctrl_out <= 0; 
            rx_done_ack <= 0;

            if (!wb_cyc_i) wb_ack_o <= 0; 

            if (rx_valid) begin
                // Luôn trả Flow Control
                if (rx_vc == 0) flow_ctrl_out[0] <= 1'b1;
                else            flow_ctrl_out[1] <= 1'b1;

                // Chỉ nhận dữ liệu nếu đúng là của mình
                if (is_my_packet) begin
                    if (state == S_WAIT_REPLY) begin
                        if (wb_we_i) begin
                            if (rx_head && rx_tail && rx_wb_ack_bit) begin
                                wb_ack_o <= 1;
                                rx_done_ack <= 1;
                            end
                        end else begin
                            if (rx_tail) begin
                                wb_dat_o <= rx_payload;
                                wb_ack_o <= 1; 
                                rx_done_ack <= 1;
                            end
                        end
                    end
                end
            end
        end
    end

    // =========================================================================
    // 4. OUTPUT ASSIGNMENT
    // =========================================================================
    always @(*) begin
        channel_out[0]    = flit_valid_out;
        channel_out[1]    = 1'b0; 
        channel_out[2]    = v_head;
        channel_out[3]    = v_tail;
        channel_out[4:35] = v_data;
    end

endmodule

