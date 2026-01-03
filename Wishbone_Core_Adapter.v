//////////////////////////////////////////////////////////////////////////////////
// Design Name: Wishbone_Core_Adapter
// Core -> Adapter Wishbone -> NI -> NoC
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

module Wishbone_Core_Adapter (
    input clk_i,
    input rst,

    // --- Giao dien phia Core ---
    input         core_req_i,    // CPU yeu cau truy cap bo nho
    input         core_we_i,     // 1 = ghi, 0 = doc
    input  [31:0] core_addr_i,   // Dia chi tu Core
    input  [31:0] core_wdata_i,  // Du lieu ghi tu Core
    input  [ 3:0] core_be_i,     // Byte enable (ghi theo byte)
    output        core_ready_o,  // Bao cho CPU biet giao dich da xong
    output [31:0] core_rdata_o,  // Du lieu doc tra ve Core

    // --- Giao dien phia Wishbone ---
    input      [31:0] wb_data_i, // Du lieu doc tu Wishbone
    input             wb_ack_i,   // Acknowledge tu Slave
    
    output reg [31:0] wb_addr_o, // Dia chi gui ra bus Wishbone
    output reg [31:0] wb_data_o, // Du lieu ghi ra Wishbone
    output reg        wb_we_o,   // Tin hieu ghi (1 = write, 0 = read)
    output reg        wb_stb_o,  // Strobe: bao hieu request hop le
    output reg        wb_cyc_o,  // Cycle: bao hieu giao dich dang dien ra
    output reg [ 3:0] wb_sel_o  // Byte select 
);
    // Du lieu doc tu Wishbone tra thang ve Core
    assign core_rdata_o = wb_data_i;

    // Tin hieu ready:
    // Core nhan duoc ready khi Slave tra ve ACK
    // Core se sample du lieu tai thoi diem nay
    assign core_ready_o = wb_ack_i; 

    // --- Dinh nghia trang thai FSM ---
    localparam IDLE        = 2'b00; // Trang thai ranh
    localparam BUS_REQUEST = 2'b01; // Dang gui request (bat STB va CYC)
    localparam BUS_WAIT    = 2'b10; // Cho ACK ha xuong 0 de an toan

    reg [1:0] state, next_state;
    reg is_write_op; // Luu loai thao tac (doc / ghi) de giu on dinh WE

    // --- 1. Thanh ghi trang thai (Sequential) ---
    always @(posedge clk_i) begin
        if (rst) begin
            state       <= IDLE;
            is_write_op <= 1'b0;
        end else begin
            state <= next_state;
            // Chi latch loai thao tac khi bat dau request moi
            if (state == IDLE && core_req_i) begin
                is_write_op <= core_we_i;
            end
        end
    end

    // --- 2. Logic chuyen trang thai (Combinational) ---
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                // Neu Core yeu cau truy cap -> bat dau request bus
                if (core_req_i) 
                    next_state = BUS_REQUEST;
            end

            BUS_REQUEST: begin
                // Giu STB/CYC cho toi khi Slave tra ve ACK
                if (wb_ack_i) 
                    next_state = BUS_WAIT; 
            end

            BUS_WAIT: begin
                // Cho Slave ha ACK xuong 0
                // Tranh truong hop ACK bi giu sang lenh ke tiep
                if (!wb_ack_i) 
                    next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // --- 3. Logic xuat tin hieu Wishbone (Combinational) ---
    always @(*) begin
        // default value
        wb_stb_o = 1'b0;
        wb_cyc_o = 1'b0;
        wb_we_o  = 1'b0;

        case (state)
            BUS_REQUEST: begin
                // Dang request bus
                wb_stb_o = 1'b1;
                wb_cyc_o = 1'b1;
                wb_we_o  = is_write_op; // Xuat WE da duoc latch
            end
            
            BUS_WAIT: begin
                // Ket thuc giao dich
                // Ha STB va CYC xuong 0
                wb_stb_o = 1'b0;
                wb_cyc_o = 1'b0; 
                wb_we_o  = 1'b0;
            end
            
            // IDLE: giu tat ca bang 0
        endcase
    end

    // --- 4. Duong du lieu (Sequential) ---
    // Chi cap nhat dia chi va du lieu khi bat dau giao dich moi
    always @(posedge clk_i) begin
        if (rst) begin
            wb_addr_o <= 32'd0;
            wb_data_o <= 32'd0;
            wb_sel_o  <= 4'b0000;
        end else begin
            if (state == IDLE && core_req_i) begin
                wb_addr_o <= core_addr_i;
                wb_data_o <= core_wdata_i;
                wb_sel_o  <= core_be_i;
            end
        end
    end


endmodule
