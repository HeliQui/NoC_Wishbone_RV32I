`timescale 1ns / 1ps

module RV32I_Wishbone_Top (
    input clk,
    input rst_n,

    // ========================================================
    // WISHBONE MASTER INTERFACE (Giao tiep ra ngoai)
    // ========================================================
    output        wbm_cyc_o,   // Cycle valid: Core muon giao tiep
    output        wbm_stb_o,   // Strobe: Dia chi/Data hop le
    output        wbm_we_o,    // Write Enable (1=Ghi, 0=Doc)
    output [31:0] wbm_adr_o,   // Address
    output [31:0] wbm_dat_o,   // Data Out (Ghi ra RAM)
    output [3:0]  wbm_sel_o,   // Byte Select
    
    input         wbm_ack_i,   // Acknowledge: RAM bao xong
    input  [31:0] wbm_dat_i    // Data In (Doc tu RAM)
);

    // --- DAY NOI NOI BO (Internal Wires) ---
    // Dung de noi giua Core va Adapter
    wire        int_mem_req;
    wire        int_mem_we;
    wire [31:0] int_mem_addr;
    wire [31:0] int_mem_wdata;
    wire [3:0]  int_mem_be;
    wire        int_mem_ready;
    wire [31:0] int_mem_rdata;

    // ========================================================
    // 1. KHOI TAO CORE (RV32I)
    // ========================================================
    RV32I core_inst (
        .clk           (clk),
        .rst_n         (rst_n),

        // Noi vao day noi bo (Internal Wires)
        .mem_req       (int_mem_req),
        .mem_we        (int_mem_we),
        .mem_addr      (int_mem_addr),
        .mem_wdata     (int_mem_wdata),
        .mem_be        (int_mem_be),
        
        // Nhan tin hieu phan hoi tu Adapter
        .mem_ready     (int_mem_ready),
        .mem_rdata     (int_mem_rdata)

        // Luu y: Debug Port trong code core cua ban dang bi comment
        // nen o day minh khong noi ra. Neu ban uncomment trong core
        // thi nho noi them vao day nhe.
    );

   // ========================================================
    // 2. KHOI TAO ADAPTER (Wishbone Adapter)
    // ========================================================
    Wishbone_Core_Adapter adapter_inst (
        .clk_i      (clk),          
        .rst_i      (~rst_n),       
        
        // --- Phia Core (Slave side cua Adapter) ---
        // Port trong Module      // Day noi trong Top
        .core_req_i   (int_mem_req),
        .core_we_i    (int_mem_we),
        .core_addr_i  (int_mem_addr),
        .core_wdata_i (int_mem_wdata),
        .core_be_i    (int_mem_be),
        .core_ready_o (int_mem_ready),
        .core_rdata_o (int_mem_rdata),

        // --- Phia Wishbone (Master side cua Adapter - Noi ra ngoai) ---
        .wb_data_i    (wbm_dat_i),    // Input Data tu Slave
        .wb_ack_i     (wbm_ack_i),    // Ack tu Slave
        
        .wb_addr_o    (wbm_adr_o),    // Output Address (Luu y: module la addr, wire la adr)
        .wb_data_o    (wbm_dat_o),    // Output Data
        .wb_we_o      (wbm_we_o),
        .wb_stb_o     (wbm_stb_o),
        .wb_cyc_o     (wbm_cyc_o),
        .wb_sel_o     (wbm_sel_o)
    );

endmodule
