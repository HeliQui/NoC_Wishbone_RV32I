//////////////////////////////////////////////////////////////////////////////////
// Design Name: wb_ram_top
// Description: Top level wrapper ket noi Wishbone Slave Interface va Memory Core
//////////////////////////////////////////////////////////////////////////////////
module wb_ram_top #(
    parameter MEM_SIZE = 1024
) (
    input wire clk_i,
    input wire rst_i,
    
    // --- Wishbone Interface (External Ports) ---
    // Tin hieu tu Master gui den (Ten chuan ngan gon: adr, dat)
    input wire [31:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    input wire [3:0]  wb_sel_i,
    input wire        wb_we_i,
    input wire        wb_cyc_i,
    input wire        wb_stb_i,
    
    // Tin hieu tra ve cho Master
    output wire [31:0] wb_dat_o, 
    output wire        wb_ack_o  
);

    // --- Day noi noi bo (Internal Wires) ---
    // Cac tin hieu nay ket noi giua Interface va RAM Core
    wire [31:0] ram_addr;
    wire [31:0] ram_wdata;
    wire [31:0] ram_rdata; // Du lieu doc tu RAM tra ve Interface
    wire [3:0]  ram_be;
    wire        ram_we;
    wire        ram_en;

    // 1. Interface (Adapter): Quan ly FSM va Handshake Wishbone
    wishbone_slave_adapter wb_slave_adapter (
        .clk_i      (clk_i),
        .rst_i      (rst_i),

        // --- Wishbone Side (Mapping Port Adapter -> Port Top) ---
        .wb_addr_i  (wb_adr_i), 
        .wb_data_i  (wb_dat_i),
        .wb_data_o  (wb_dat_o),   
        .wb_we_i    (wb_we_i),
        .wb_stb_i   (wb_stb_i),
        .wb_cyc_i   (wb_cyc_i),
        .wb_sel_i   (wb_sel_i),
        .wb_ack_o   (wb_ack_o),

        // --- Memory Side (Mapping Port Adapter -> Internal Wires) ---
        // Luu y: Ten port phai khop voi definition cua wishbone_slave_adapter
        .mem_addr_o (ram_addr),   // Adapter output -> Wire
        .mem_wdata_o(ram_wdata),  // Adapter output -> Wire
        .mem_rdata_i(ram_rdata),  // Wire -> Adapter input
        .mem_we_o   (ram_we),     
        .mem_en_o   (ram_en),
        .mem_sel_o  (ram_be)      
    );

    // 2. RAM Core: Module luu tru du lieu thuc te
    ram #(
        .MEM_SIZE(MEM_SIZE)
    ) ram_inst (
        .clk        (clk_i),
        
        // --- Input tu Interface (Noi vao day noi bo) ---
        .addr       (ram_addr),
        .wdata      (ram_wdata), 
        .be         (ram_be),    
        .we         (ram_we),
        .en         (ram_en),    
        
        // --- Output tra ve Interface ---
        .rdata      (ram_rdata)  
    );

endmodule