module fetch_decode (
    input clk,
    input reset,

    // NEW CONTROL SIGNALS
    input stall_F,      // Stall Fetch (freeze PC)
    input stall_D,      // Stall Decode (freeze decode outputs)
    input flush_D,      // Flush Decode (insert NOP)

    // Instruction memory interface
    input  [31:0] imem_data0,  // instruction at PC
    input  [31:0] imem_data1,  // instruction at PC+4
    output [31:0] imem_addr0,
    output [31:0] imem_addr1,

    // Outputs to Decode Stage
    output reg [31:0] instr0_out,
    output reg [31:0] instr1_out,
    output reg [31:0] PC_out
);

    reg [31:0] PC_in;
    wire [31:0] PC_next;


    // PROGRAM COUNTER UPDATE WITH STALL SUPPORT
 
    assign PC_next = PC_in + 8;

    always @(posedge clk or posedge reset) begin
        if (reset)
            PC_in <= 32'h00000000;
        else if (!stall_F)
            PC_in <= PC_next;
        // else stall_F=1 → keep old PC_in (stall fetch)
    end

    assign imem_addr0 = PC_in;
    assign imem_addr1 = PC_in + 4;

   
    // DECODE STAGE PIPELINE REGISTER WITH STALL + FLUSH SUPPORT
  
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            instr0_out <= 32'h00000013; // NOP
            instr1_out <= 32'h00000013; // NOP
            PC_out     <= 0;
        end
        
        else if (flush_D) begin
            // Flush decode stage (branch mispredict)
            instr0_out <= 32'h00000013;  // NOP
            instr1_out <= 32'h00000013;  // NOP
            // PC_out usually flushed or unchanged depending on design
        end

        else if (!stall_D) begin
            // Normal operation — update decode pipeline registers
            instr0_out <= imem_data0;
            instr1_out <= imem_data1;
            PC_out     <= PC_in;
        end
        
        // else stall_D = 1 → keep previous values (stall decode)
    end

endmodule
