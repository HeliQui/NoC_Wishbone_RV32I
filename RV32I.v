//////////////////////////////////////////////////////////////////////////////////
// Design Name: RV32I
// Core RiscV 32I Single Cycle, Imem local.
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
module RV32I(
    input clk,
    input rst_n, 

    // Giao tiep Memory (Data Memory)
    input             mem_ready,
    input  [31:0]     mem_rdata,
    
    output            mem_req,
    output            mem_we,
    output [31:0]     mem_addr,
    output [31:0]     mem_wdata, // Noi vao LSU
    output [3:0]      mem_be    // Noi vao LSU
);

    // --- Internal Wires ---
    wire [31:0] pc_current, pc_next;
    wire [31:0] pc_plus4, pc_branch_target, pc_jalr_target;
    wire [31:0] instr;
     
    // Control Signals
    wire mem_read, mem_write, jump, reg_write, branch, mux_jalr, write_back;
    wire [1:0] alu_src_a, alu_src_b;
    wire [3:0] alu_op;
    wire [2:0] imm_control;

    // Data Signals
    wire [31:0] rd1_data, rd2_data, wb_data;
    wire [31:0] imm_ext, src_a, src_b, alu_result;
    wire [31:0] load_data_processed; // Ket qua tu LSU
    wire alu_zero;

    // ----------------------------------------------------
    // STALL LOGIC
    // ----------------------------------------------------
    assign mem_req = mem_read | mem_write;
    wire stall = mem_req & ~mem_ready;
    wire pc_enable      = ~stall;
    wire real_reg_write = reg_write & ~stall;

    // ----------------------------------------------------
    // OUTPUT ASSIGNMENT
    // ----------------------------------------------------
    assign mem_we   = mem_write;
    assign mem_addr = alu_result;
    
    // ----------------------------------------------------
    // MODULE INSTANTIATIONS
    // ----------------------------------------------------

    // 1. LSU: Load Store Unit (Xu ly Load/Store Logic)
    Load_Store_Unit lsu_inst (
        .funct3        (instr[14:12]),
        .addr_offset   (alu_result[1:0]),
        .mem_write     (mem_write),
        .data_store_in (rd2_data),        // Data tu RegFile
        .data_load_in  (mem_rdata),       // Data tu Memory
        
        .mem_be        (mem_be),          // -> Output ra ngoai
        .mem_wdata     (mem_wdata),       // -> Output ra ngoai
        .data_load_out (load_data_processed) // Data Load da xu ly xong
    );

    // 2. PC
    PC pc_inst (
        .clk(clk), .en(pc_enable), .rst_n(rst_n),
        .addr_in(pc_next), .addr_out(pc_current)
    );

    // 3. Instruction Memory (Internal)
    instruction_Mem imem_inst (
        .addr(pc_current), .inst(instr)
    );

    // 4. Control Unit
    Control_Unit ctrl_inst (
        .opcode(instr[6:0]), .funct3(instr[14:12]), .funct7(instr[31:25]),
        .MemReadD(mem_read), .MemWriteD(mem_write), .JumpD(jump),
        .RegWriteD(reg_write), .BranchD(branch), .MuxjalrD(mux_jalr),
        .WriteBackD(write_back), .ALUSrcA_D(alu_src_a), .ALUSrcB_D(alu_src_b),
        .ALUOpD(alu_op), .ImmControlD(imm_control)
    );

    // 5. Register File
    rf_32_32 rf_inst (
        .clk(clk), .rst_n(rst_n), .reg_write(real_reg_write),
        .ra1(instr[19:15]), .ra2(instr[24:20]), .wa(instr[11:7]),
        .data_write(wb_data), // Data ghi nguoc ve (Write Back)
        .rd1(rd1_data), .rd2(rd2_data)
    );

    // 6. Sign Extend
    Sign_Extend imm_gen_inst (
        .inst(instr[31:7]), .control(imm_control), .imm(imm_ext)
    );

    // 7. ALU Logic
    assign src_a = (alu_src_a == 2'b00) ? rd1_data :
                   (alu_src_a == 2'b01) ? pc_current : 32'b0;

    assign src_b = (alu_src_b == 2'b00) ? rd2_data :
                   (alu_src_b == 2'b01) ? imm_ext :
                   (alu_src_b == 2'b10) ? 32'd4 : 32'd0;

    alu alu_inst (
        .A(src_a), .B(src_b), .opcode(alu_op), .branch(instr[14:12]),
        .result(alu_result), .Z(alu_zero)
    );

    // ----------------------------------------------------
    // NEXT PC & WRITE BACK MUX
    // ----------------------------------------------------
     
    // Next PC Logic
    assign pc_plus4             = pc_current + 4;
    assign pc_branch_target = pc_current + imm_ext;
    assign pc_jalr_target   = rd1_data + imm_ext;

    reg [31:0] pc_next_mux;
    always @(*) begin
        if (mux_jalr) pc_next_mux = pc_jalr_target;
        else if ((branch & alu_zero) | jump) pc_next_mux = pc_branch_target;
        else pc_next_mux = pc_plus4;
    end
    assign pc_next = pc_next_mux;

    // Write Back Logic (Chon giua ALU Result va Data Load da xu ly boi LSU)
    assign wb_data = (write_back) ? load_data_processed : alu_result;

endmodule
