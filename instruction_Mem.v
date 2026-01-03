module instruction_Mem #(
    parameter IMEM_FILE = ""   
)(
    input  [31:0] addr,
    output reg [31:0] inst
);

    reg [31:0] i_mem [0:63];

    initial begin
        if (IMEM_FILE != "") begin
            $readmemh(IMEM_FILE, i_mem);
        end
        else begin
            $display("WARNING: IMEM_FILE is empty, instruction memory not initialized");
        end
    end

    always @(*) begin
        inst = i_mem[addr[31:2]]; // word-aligned
    end

endmodule