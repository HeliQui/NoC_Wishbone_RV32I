`timescale 1ns / 1ps

module ram #(
    // Total size in Bytes (Example: 1024 Bytes = 256 Words)
    parameter MEM_SIZE = 1024 
) (
    input wire clk,

    // Basic RAM Interface
    input wire [31:0] addr,    // Byte Address (from CPU)
    input wire [31:0] wdata,   // Write Data
    input wire [3:0]  be,      // Byte Enable (Active High)
    input wire        we,      // Write Enable
    input wire        en,      // Chip Enable (Valid Request)

    output reg [31:0] rdata    // Read Data
);

    // Calculate depth based on 32-bit word width
    // 1024 Bytes / 4 = 256 Words
    localparam MEM_DEPTH = MEM_SIZE / 4;

    // Define Memory Array: Width 32-bit
    reg [31:0] mem [0:MEM_DEPTH-1];

    // --- RAM LOGIC ---
    always @(posedge clk) begin
        if (en) begin
            // --- WRITE OPERATION ---
            // Use addr[31:2] to align to Word boundaries (Word Index)
            if (we) begin
                if (be[0]) mem[addr[31:2]][7:0]   <= wdata[7:0];
                if (be[1]) mem[addr[31:2]][15:8]  <= wdata[15:8];
                if (be[2]) mem[addr[31:2]][23:16] <= wdata[23:16];
                if (be[3]) mem[addr[31:2]][31:24] <= wdata[31:24];
            end 
            
            // --- READ OPERATION ---
            // Read the full 32-bit word
            rdata <= mem[addr[31:2]];
        end
    end
    
    // Optional: Memory Initialization (for simulation)
    // initial begin
    //    $readmemh("program.hex", mem);
    // end

endmodule