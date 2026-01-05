module ni_core
#(
    parameter MY_X = 0,
    parameter MY_Y = 0,
    parameter BUFFER_DEPTH = 3 
)
(
    input clk,
    input rst, 

    // --- GIAO TIẾP WISHBONE SLAVE ---
    input             wb_cyc_i,   
    input             wb_stb_i,   
    input             wb_we_i,     
    input  [31:0]     wb_adr_i,   
    input  [31:0]     wb_dat_i,   
    input  [3:0]      wb_sel_i,   
    output reg        wb_ack_o,   
    output reg [31:0] wb_dat_o, 

    // --- GIAO TIẾP ROUTER ---
    output reg [0:35] channel_out, 
    input      [0:35] channel_in,

    // --- FLOW CONTROL (Encoded: [0]=Valid, [1]=VC_ID) ---
    input      [0:1]  flow_ctrl_in, 
    output reg [0:1]  flow_ctrl_out 
);

    // =========================================================================
    // 1. ROUTING LOGIC
    // =========================================================================
    reg [1:0] dest_x, dest_y;
    reg [2:0] next_port_bin; 

    // A. MAPPING (Address Decoder)
    always @(*) begin
        case(wb_adr_i[31:28]) 
            4'h0:    {dest_x, dest_y} = 4'b01_01; // RAM 1 (1,1)
            4'h1:    {dest_x, dest_y} = 4'b10_01; // LED Matrix (2,1)
            4'h2:    {dest_x, dest_y} = 4'b00_01; // Timer (0,1)
            4'h3:    {dest_x, dest_y} = 4'b01_00; // GPIO (1,0)
            4'h4:    {dest_x, dest_y} = 4'b01_10; // UART (1,2)
            default: {dest_x, dest_y} = {MY_X[1:0], MY_Y[1:0]}; 
        endcase
    end

    // B. DIRECTION CALCULATION (XY Routing)
    always @(*) begin
        if (dest_x > MY_X)      next_port_bin = 3'd1; // East
        else if (dest_x < MY_X) next_port_bin = 3'd0; // West
        else if (dest_y > MY_Y) next_port_bin = 3'd3; // North
        else if (dest_y < MY_Y) next_port_bin = 3'd2; // South
        else                    next_port_bin = 3'd4; // Local
    end

    // =========================================================================
    // 2. TX LOGIC & CREDIT MANAGEMENT
    // =========================================================================
    
    reg [3:0] credit_vc0; 
    reg [3:0] credit_vc1; 

    // Flow control input decoding
    wire cred_valid_in = flow_ctrl_in[0];
    wire cred_vc_id_in = flow_ctrl_in[1];

    reg flit_valid_out; 
    wire router_ready = (credit_vc0 > 0);
    // Logic tăng credit: Có Valid VÀ đúng VC ID = 0
    wire credit_inc_vc0 = cred_valid_in && (cred_vc_id_in == 1'b0);
    // Logic giảm credit: Khi ta đang gửi flit đi (flit_valid_out đang ở mức 1 từ chu kỳ trước)
    wire credit_dec_vc0 = flit_valid_out;
    // -----------------------------------------------

    // Quản lý Credit VC0 (Request Packet)
    always @(posedge clk or posedge rst) begin
        if (rst) credit_vc0 <= BUFFER_DEPTH;
        else begin
            case ({credit_inc_vc0, credit_dec_vc0})
                2'b10: credit_vc0 <= credit_vc0 + 1;
                2'b01: credit_vc0 <= credit_vc0 - 1;
                default: credit_vc0 <= credit_vc0;
            endcase
        end
    end

    // Quản lý Credit VC1 (Response Packet)
    wire credit_inc_vc1 = cred_valid_in && (cred_vc_id_in == 1'b1);
    // -----------------------------------------------

    always @(posedge clk or posedge rst) begin
        if (rst) credit_vc1 <= BUFFER_DEPTH;
        else begin
             if (credit_inc_vc1) credit_vc1 <= credit_vc1 + 1;
        end
    end

    // --- TX STATE MACHINE ---
    localparam S_IDLE       = 0;
    localparam S_SEND_HEAD  = 1;
    localparam S_SEND_DATA  = 2; 
    localparam S_WAIT_REPLY = 3;

    reg [2:0] state;
    reg v_head, v_tail;
    reg [31:0] v_data;
    wire wb_req = wb_cyc_i & wb_stb_i; 
    reg rx_done_ack; 

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            flit_valid_out <= 0;
            v_head <= 0; v_tail <= 0; v_data <= 0;
        end else begin
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
                            // Check credit
                            if ( (credit_vc0 >= 4'd2) || (cred_valid_in && cred_vc_id_in == 0) ) 
                                flit_valid_out <= 1;
                            else 
                                flit_valid_out <= 0;
                            
                            v_head <= 0; v_tail <= 1; 
                            v_data <= wb_dat_i; 
                        end else begin
                            state <= S_WAIT_REPLY;
                            flit_valid_out <= 0; 
                        end
                    end 
                end

                S_SEND_DATA: begin
                    if (router_ready) begin
                        flit_valid_out <= 0; 
                        state <= S_WAIT_REPLY;
                    end else begin
                        flit_valid_out <= 1; 
                    end
                end

                S_WAIT_REPLY: begin
                    flit_valid_out <= 0;
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
    // 3. RX LOGIC (FILTER & HANDSHAKE)
    // =========================================================================
    wire rx_valid = channel_in[0];
    wire rx_vc    = channel_in[1];
    wire rx_head  = channel_in[2];
    wire rx_tail  = channel_in[3];
    wire [31:0] rx_payload = channel_in[4:35];
    wire rx_wb_ack_bit = rx_payload[20];

    wire [1:0] pkt_dest_x = rx_payload[28:27];
    wire [1:0] pkt_dest_y = rx_payload[26:25];
    reg is_my_packet;

    always @(*) begin
        if (rx_valid && rx_head) begin
            if (pkt_dest_x == MY_X[1:0] && pkt_dest_y == MY_Y[1:0])
                is_my_packet = 1'b1;
            else 
                is_my_packet = 1'b0; 
        end else begin
            is_my_packet = 1'b1; 
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin 
            wb_ack_o <= 0; wb_dat_o <= 0; flow_ctrl_out <= 0; rx_done_ack <= 0;
        end else begin
            wb_ack_o <= 0;
            flow_ctrl_out <= 0; 
            rx_done_ack <= 0;

            if (!wb_cyc_i) wb_ack_o <= 0; 

            if (rx_valid) begin
                // --- FLOW CONTROL RETURN ---
                flow_ctrl_out[0] <= 1'b1;  // Valid
                flow_ctrl_out[1] <= rx_vc; // VC ID
                // ---------------------------

                if (is_my_packet) begin
                    if (state == S_WAIT_REPLY) begin
                        if (wb_we_i) begin
                            // Write Response
                            if (rx_head && rx_tail && rx_wb_ack_bit) begin
                                wb_ack_o <= 1;
                                rx_done_ack <= 1;
                            end
                        end else begin
                            // Read Response
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
        channel_out[1]    = 1'b0; // VC ID
        channel_out[2]    = v_head;
        channel_out[3]    = v_tail;
        channel_out[4:35] = v_data;
    end

endmodule

