
// Part D: MEMORY & WRITE-BACK STAGE

// This module handles:
// 1. Data Memory Access (Load/Store)
// 2. Write-Back Mux (Selects Memory Data vs ALU Result)
// 3. Outputs 'wb_enable' signals to update the Register File


module memory_wb_stage (
    input wire clk,
    input wire reset,

    // -------------------- SLOT 0 INPUTS --------------------
    input wire [31:0] alu_res0,      // Address for Load/Store
    input wire [31:0] wdata0,        // Data to Store
    input wire        mem_read0,
    input wire        mem_write0,
    input wire        reg_write0,
    input wire [4:0]  rd0,

    // SLOT 1 INPUTS 
    input wire [31:0] alu_res1,
    input wire [31:0] wdata1,
    input wire        mem_read1,
    input wire        mem_write1,
    input wire        reg_write1,
    input wire [4:0]  rd1,

    // OUTPUTS TO REGISTER FILE 
    output wire [31:0] wb_data0,      // Final data to write to RegFile
    output wire [4:0]  wb_rd0,        // Dest Register Index
    output wire        wb_en0,        // Write Enable

    output wire [31:0] wb_data1,
    output wire [4:0]  wb_rd1,
    output wire        wb_en1
);

    // Data Memory (Dual Port Simulation)
   
    reg [31:0] dmem [0:1023];  // 4KB Data Memory
    reg [31:0] mem_out0;
    reg [31:0] mem_out1;

    // Memory Access Logic
    // Note: We use blocking assignment for simulation read, 
    // but real RAM usually has a clock edge read latency.
    always @(posedge clk) begin
        // SLOT 0 Write
        if (mem_write0) 
            dmem[alu_res0[11:2]] <= wdata0; // Word aligned index
        
        // SLOT 1 Write (Priority check: if same address, Slot 1 overwrites Slot 0 in sequence)
        if (mem_write1)
            dmem[alu_res1[11:2]] <= wdata1;
    end

    // Asynchronous Read (for simple 5-stage pipeline simulation)
    // In a real design, this is typically synchronous.
    always @(*) begin
        mem_out0 = (mem_read0) ? dmem[alu_res0[11:2]] : 32'b0;
        mem_out1 = (mem_read1) ? dmem[alu_res1[11:2]] : 32'b0;
    end


    // Write-Back MUX

    // Select between Memory Output (Load) and ALU Result (Arithmetic)
    
    assign wb_data0 = (mem_read0) ? mem_out0 : alu_res0;
    assign wb_rd0   = rd0;
    assign wb_en0   = reg_write0 && (rd0 != 0); // Never write to x0

    assign wb_data1 = (mem_read1) ? mem_out1 : alu_res1;
    assign wb_rd1   = rd1;
    assign wb_en1   = reg_write1 && (rd1 != 0);

endmodule