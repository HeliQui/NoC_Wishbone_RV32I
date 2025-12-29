`timescale 1ns / 1ps
module Load_Store_Unit(
    // Inputs tu Core
    input [2:0]  funct3,        // Lay tu instr[14:12] (SB, SH, SW, LB, LH...)
    input [1:0]  addr_offset,   // 2 bit cuoi cua dia chi (alu_result[1:0])
    input        mem_write,     // Tin hieu cho phep ghi
    input [31:0] data_store_in, // Du lieu tu RS2 muon ghi xuong Mem (chua align)
    
    // Inputs tu Memory
    input [31:0] data_load_in,  // Du lieu tho doc tu Memory (32-bit)

    // Outputs ra Memory (Store path)
    output reg [3:0]  mem_be,      // Mask ghi
    output reg [31:0] mem_wdata,   // Du lieu da duoc align dung lan

    // Outputs ve Core (Load path)
    output reg [31:0] data_load_out // Du lieu da duoc cat got va mo rong dau
);

    // ====================================================
    // 1. LOGIC STORE (Core -> Memory)
    // ====================================================
    
    // A. Data Alignment (Dua data vao dung lan)
    always @(*) begin
        case (funct3)
            3'b000: // SB
                mem_wdata = {data_store_in[7:0], data_store_in[7:0], data_store_in[7:0], data_store_in[7:0]};
            3'b001: // SH
                mem_wdata = {data_store_in[15:0], data_store_in[15:0]};
            default: // SW
                mem_wdata = data_store_in;
        endcase
    end

    // B. Byte Enable Calculation (Tinh Mask)
    always @(*) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB
                    case (addr_offset)
                        2'b00: mem_be = 4'b0001;
                        2'b01: mem_be = 4'b0010;
                        2'b10: mem_be = 4'b0100;
                        2'b11: mem_be = 4'b1000;
                    endcase
                end
                3'b001: begin // SH
                    case (addr_offset[1])
                        1'b0: mem_be = 4'b0011;
                        1'b1: mem_be = 4'b1100;
                    endcase
                end
                default: mem_be = 4'b1111; // SW
            endcase
        end else begin
            mem_be = 4'b0000;
        end
    end

    // ====================================================
    // 2. LOGIC LOAD (Memory -> Core)
    // ====================================================
    always @(*) begin
        case (funct3)
            // LB
            3'b000: begin 
                case (addr_offset)
                    2'b00: data_load_out = {{24{data_load_in[7]}},  data_load_in[7:0]};
                    2'b01: data_load_out = {{24{data_load_in[15]}}, data_load_in[15:8]};
                    2'b10: data_load_out = {{24{data_load_in[23]}}, data_load_in[23:16]};
                    2'b11: data_load_out = {{24{data_load_in[31]}}, data_load_in[31:24]};
                endcase
            end
            // LH
            3'b001: begin 
                case (addr_offset[1])
                    1'b0: data_load_out = {{16{data_load_in[15]}}, data_load_in[15:0]};
                    1'b1: data_load_out = {{16{data_load_in[31]}}, data_load_in[31:16]};
                endcase
            end
            // LW
            3'b010: data_load_out = data_load_in;
            // LBU
            3'b100: begin 
                case (addr_offset)
                    2'b00: data_load_out = {24'b0, data_load_in[7:0]};
                    2'b01: data_load_out = {24'b0, data_load_in[15:8]};
                    2'b10: data_load_out = {24'b0, data_load_in[23:16]};
                    2'b11: data_load_out = {24'b0, data_load_in[31:24]};
                endcase
            end
            // LHU
            3'b101: begin 
                case (addr_offset[1])
                    1'b0: data_load_out = {16'b0, data_load_in[15:0]};
                    1'b1: data_load_out = {16'b0, data_load_in[31:16]};
                endcase
            end
            default: data_load_out = data_load_in;
        endcase
    end

endmodule