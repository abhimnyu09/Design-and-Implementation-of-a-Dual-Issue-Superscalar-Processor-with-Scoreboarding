
// Part C: EXECUTION STAGE (Dual Issue)

// This module performs ALU operations for both pipelines.
// It assumes a "Decoder" has already extracted operands & immediates.


module execute_stage (
    input wire clk,
    input wire reset,

    // Pipeline Control
    input wire stall_E,   // Stall Execution

    //SLOT 0 INPUTS
    input wire [3:0]  alu_op0,      // ALU Control Code (e.g., 0000=ADD)
    input wire [31:0] rdata0_1,     // Rs1 Value
    input wire [31:0] rdata0_2,     // Rs2 Value
    input wire [31:0] imm0,         // Immediate Value
    input wire        use_imm0,     // 1 = Use Immediate, 0 = Use Rs2
    input wire        mem_read0,    // Control propagation
    input wire        mem_write0,
    input wire        reg_write0,
    input wire [4:0]  rd0,

    //  SLOT 1 INPUTS
    input wire [3:0]  alu_op1,
    input wire [31:0] rdata1_1,
    input wire [31:0] rdata1_2,
    input wire [31:0] imm1,
    input wire        use_imm1,
    input wire        mem_read1,
    input wire        mem_write1,
    input wire        reg_write1,
    input wire [4:0]  rd1,

    //OUTPUTS TO MEM/WB 
    output reg [31:0] alu_res0,     // ALU Result 0 (or Mem Addr)
    output reg [31:0] wdata0,       // Store Data 0
    output reg        mem_read0_out,
    output reg        mem_write0_out,
    output reg        reg_write0_out,
    output reg [4:0]  rd0_out,

    output reg [31:0] alu_res1,     // ALU Result 1
    output reg [31:0] wdata1,       // Store Data 1
    output reg        mem_read1_out,
    output reg        mem_write1_out,
    output reg        reg_write1_out,
    output reg [4:0]  rd1_out
);

    // ALU Function Parameters
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_AND = 4'b0010;
    localparam ALU_OR  = 4'b0011;
    localparam ALU_XOR = 4'b0100;
    localparam ALU_SLL = 4'b0101;
    localparam ALU_SRL = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    
    // Combinational ALU Logic Function

    function [31:0] get_alu_result;
        input [3:0] op;
        input [31:0] a;
        input [31:0] b;
        begin
            case (op)
                ALU_ADD: get_alu_result = a + b;
                ALU_SUB: get_alu_result = a - b;
                ALU_AND: get_alu_result = a & b;
                ALU_OR:  get_alu_result = a | b;
                ALU_XOR: get_alu_result = a ^ b;
                ALU_SLL: get_alu_result = a << b[4:0];
                ALU_SRL: get_alu_result = a >> b[4:0];
                ALU_SLT: get_alu_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                default: get_alu_result = 32'd0;
            endcase
        end
    endfunction

    // Internal Signals

    wire [31:0] op0_b_final = (use_imm0) ? imm0 : rdata0_2;
    wire [31:0] op1_b_final = (use_imm1) ? imm1 : rdata1_2;

    wire [31:0] alu0_calc = get_alu_result(alu_op0, rdata0_1, op0_b_final);
    wire [31:0] alu1_calc = get_alu_result(alu_op1, rdata1_1, op1_b_final);

    
    // Pipeline Register (Execute -> Mem/WB)
  
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            {mem_read0_out, mem_write0_out, reg_write0_out} <= 0;
            {mem_read1_out, mem_write1_out, reg_write1_out} <= 0;
            rd0_out <= 0; rd1_out <= 0;
            alu_res0 <= 0; wdata0 <= 0;
            alu_res1 <= 0; wdata1 <= 0;
        end 
        else if (!stall_E) begin
            // Slot 0
            alu_res0       <= alu0_calc;
            wdata0         <= rdata0_2; // For STORE instructions
            rd0_out        <= rd0;
            mem_read0_out  <= mem_read0;
            mem_write0_out <= mem_write0;
            reg_write0_out <= reg_write0;

            // Slot 1
            alu_res1       <= alu1_calc;
            wdata1         <= rdata1_2;
            rd1_out        <= rd1;
            mem_read1_out  <= mem_read1;
            mem_write1_out <= mem_write1;
            reg_write1_out <= reg_write1;
        end
    end

endmodule