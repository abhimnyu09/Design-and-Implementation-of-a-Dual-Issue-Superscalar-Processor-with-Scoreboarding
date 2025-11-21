`timescale 1ns / 1ps

module tb_top_processor;

    // 1. CLOCK & RESET
    reg clk;
    reg reset;

    // 2. MEMORY & DEBUG INTERFACE
    wire [31:0] imem_addr0, imem_addr1;
    reg  [31:0] imem_data0, imem_data1;
    wire [31:0] debug_pc;
    wire [31:0] wb0, wb1;

    // 3. INSTANTIATE PROCESSOR
    top_processor u_cpu (
        .clk(clk), .reset(reset),
        .imem_addr0(imem_addr0), .imem_data0(imem_data0),
        .imem_addr1(imem_addr1), .imem_data1(imem_data1),
        .debug_pc_out(debug_pc), 
        .debug_wb_data0(wb0), .debug_wb_data1(wb1)
    );

    // 4. CLOCK
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 5. INSTRUCTION MEMORY
    reg [31:0] instr_rom [0:255];
    always @(*) begin
        imem_data0 = instr_rom[imem_addr0[9:2]]; 
        imem_data1 = instr_rom[imem_addr1[9:2]];
    end

    integer i;
    initial begin
        // Init NOPs
        for (i=0; i<256; i=i+1) instr_rom[i] = 32'h00000013; 

        // ============================================================
        // PHASE 1: THE "OBSTACLE COURSE" (Multiple Stalls)
        // We create dependencies back-to-back to test Scoreboard recovery.
        // ============================================================

        // --- Stall Event 1 ---
        // T=0: Write x1 (Value 10) and x2 (Value 20)
        instr_rom[0] = 32'h00A00093; // ADDI x1, x0, 10
        instr_rom[1] = 32'h01400113; // ADDI x2, x0, 20

        // T=1: READ x1, x2 immediately (RAW Hazard -> STALL 1)
        instr_rom[2] = 32'h00208F33; // ADD x30, x1, x2 (Result 30)
        instr_rom[3] = 32'h00000013; // NOP

        // --- Stall Event 2 (Chained Dependency) ---
        // T=2 (Post-Stall): Write x3 (Value 5)
        instr_rom[4] = 32'h00500193; // ADDI x3, x0, 5
        instr_rom[5] = 32'h00000013; // NOP

        // T=3: READ x3 immediately (RAW Hazard -> STALL 2)
        // Also depends on x30 from the previous stall event!
        instr_rom[6] = 32'h01E18F33; // ADD x30, x3, x30 (Result 5+30=35)
        instr_rom[7] = 32'h00000013; // NOP

        // ============================================================
        // PHASE 2: THE "HIGHWAY" (Heavy Parallel Calculation)
        // Vector Addition of 4 pairs (Array Size = 4)
        // C[0]..C[3] = A[0]..A[3] + B[0]..B[3]
        // ============================================================

        // --- SETUP: Load Registers (Parallel) ---
        // Load Array A into x10, x11, x12, x13
        instr_rom[8]  = 32'h00A00513; // ADDI x10, x0, 10
        instr_rom[9]  = 32'h01400593; // ADDI x11, x0, 20
        instr_rom[10] = 32'h01E00613; // ADDI x12, x0, 30
        instr_rom[11] = 32'h02800693; // ADDI x13, x0, 40

        // Load Array B into x14, x15, x16, x17
        instr_rom[12] = 32'h00100713; // ADDI x14, x0, 1
        instr_rom[13] = 32'h00200793; // ADDI x15, x0, 2
        instr_rom[14] = 32'h00300813; // ADDI x16, x0, 3
        instr_rom[15] = 32'h00400893; // ADDI x17, x0, 4

        // Bubble (Wait for setups to finish)
        instr_rom[16] = 32'h00000013;
        instr_rom[17] = 32'h00000013;

        // --- EXECUTION: 4 Parallel Additions ---
        
        // Pair 1: C[0] (x20) and C[1] (x21)
        instr_rom[18] = 32'h00E50A33; // ADD x20, x10, x14 (10+1=11)
        instr_rom[19] = 32'h00F58AB3; // ADD x21, x11, x15 (20+2=22)

        // Pair 2: C[2] (x22) and C[3] (x23)
        instr_rom[20] = 32'h01060B33; // ADD x22, x12, x16 (30+3=33)
        instr_rom[21] = 32'h01168BB3; // ADD x23, x13, x17 (40+4=44)

        // ============================================================

        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top_processor);

        reset = 1; #20; reset = 0;
        $display("--- Start: Multi-Stall & Heavy Calculation Test ---");
        #300; // Increased run time to catch all results
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (!reset && (wb0 !== 0 || wb1 !== 0)) begin
            $display("Time=%0t | PC=%d | Result A: %d | Result B: %d", 
                     $time, debug_pc, $signed(wb0), $signed(wb1));
        end
    end

endmodule