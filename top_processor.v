
// TOP LEVEL SUPERSCALAR PROCESSOR
// Fixed: Decoupled stall_E from stall_D to prevent deadlock


module top_processor (
    input clk,
    input reset,
    
    output [31:0] imem_addr0,
    input  [31:0] imem_data0,
    output [31:0] imem_addr1,
    input  [31:0] imem_data1,

    output [31:0] debug_pc_out,
    output [31:0] debug_wb_data0,
    output [31:0] debug_wb_data1
);

  
    // 1. WIRES & INTERCONNECTS

    
    wire stall_F, stall_D, stall_E, flush_D;
    
    wire [31:0] instr0, instr1;
    wire [31:0] pc_current;
    assign debug_pc_out = pc_current;

    reg [3:0]  alu_op0, alu_op1;
    reg        mem_read0, mem_write0, reg_write0, use_imm0;
    reg        mem_read1, mem_write1, reg_write1, use_imm1;
    reg [31:0] imm0, imm1;
    
    wire [4:0] rs1_0 = instr0[19:15];
    wire [4:0] rs2_0 = instr0[24:20];
    wire [4:0] rd_0  = instr0[11:7];
    
    wire [4:0] rs1_1 = instr1[19:15];
    wire [4:0] rs2_1 = instr1[24:20];
    wire [4:0] rd_1  = instr1[11:7];

    wire [31:0] rdata0_1, rdata0_2;
    wire [31:0] rdata1_1, rdata1_2;

    wire [31:0] ex_res0, ex_wdata0;
    wire [31:0] ex_res1, ex_wdata1;
    wire [4:0]  ex_rd0, ex_rd1;
    wire        ex_mr0, ex_mw0, ex_rw0;
    wire        ex_mr1, ex_mw1, ex_rw1;

    wire [31:0] wb_data0, wb_data1;
    wire [4:0]  wb_rd0, wb_rd1;
    wire        wb_en0, wb_en1;

    assign debug_wb_data0 = wb_data0;
    assign debug_wb_data1 = wb_data1;


    // 2. MODULE INSTANTIATION


    // --- STAGE A: FETCH ---
    fetch_decode u_fetch (
        .clk(clk), .reset(reset),
        .stall_F(stall_F), .stall_D(stall_D), .flush_D(flush_D),
        .imem_data0(imem_data0), .imem_data1(imem_data1),
        .imem_addr0(imem_addr0), .imem_addr1(imem_addr1),
        .instr0_out(instr0), .instr1_out(instr1), .PC_out(pc_current)
    );

    // --- STAGE B1: DECODE LOGIC ---
    always @(*) begin
        decode_instruction(instr0, alu_op0, mem_read0, mem_write0, reg_write0, use_imm0, imm0);
        decode_instruction(instr1, alu_op1, mem_read1, mem_write1, reg_write1, use_imm1, imm1);
    end

    // --- STAGE B2: SCOREBOARD ---
    scoreboard u_scoreboard (
        .clk(clk), .rst(reset),
        .d0_rd(rd_0), .d0_rs1(rs1_0), .d0_rs2(rs2_0), .d0_writes(reg_write0),
        .d1_rd(rd_1), .d1_rs1(rs1_1), .d1_rs2(rs2_1), .d1_writes(reg_write1),
        .wb_rd0(wb_rd0), .wb_en0(wb_en0),
        .wb_rd1(wb_rd1), .wb_en1(wb_en1),
        .stall_F(stall_F), .stall_D(stall_D), .flush_D(flush_D)
    );

    // --- REGISTER FILE ---
    reg_file_4r2w u_regfile (
        .clk(clk), .rst(reset),
        .raddr0_1(rs1_0), .rdata0_1(rdata0_1),
        .raddr0_2(rs2_0), .rdata0_2(rdata0_2),
        .raddr1_1(rs1_1), .rdata1_1(rdata1_1),
        .raddr1_2(rs2_1), .rdata1_2(rdata1_2),
        .waddr0(wb_rd0), .wdata0(wb_data0), .wen0(wb_en0),
        .waddr1(wb_rd1), .wdata1(wb_data1), .wen1(wb_en1)
    );

    // --- STAGE C: EXECUTE ---
    // *** DEADLOCK FIX: Do NOT stall Execute when Decode stalls. ***
    // Execute must continue to flush the previous instruction (ADDI)
    // so that Write-Back happens and clears the Scoreboard.
    assign stall_E = 0; 

    execute_stage u_execute (
        .clk(clk), .reset(reset), .stall_E(stall_E),
        .alu_op0(alu_op0), .rdata0_1(rdata0_1), .rdata0_2(rdata0_2),
        .imm0(imm0), .use_imm0(use_imm0), .rd0(rd_0),
        .mem_read0(mem_read0), .mem_write0(mem_write0), .reg_write0(reg_write0),
        .alu_op1(alu_op1), .rdata1_1(rdata1_1), .rdata1_2(rdata1_2),
        .imm1(imm1), .use_imm1(use_imm1), .rd1(rd_1),
        .mem_read1(mem_read1), .mem_write1(mem_write1), .reg_write1(reg_write1),
        .alu_res0(ex_res0), .wdata0(ex_wdata0), 
        .mem_read0_out(ex_mr0), .mem_write0_out(ex_mw0), .reg_write0_out(ex_rw0), .rd0_out(ex_rd0),
        .alu_res1(ex_res1), .wdata1(ex_wdata1),
        .mem_read1_out(ex_mr1), .mem_write1_out(ex_mw1), .reg_write1_out(ex_rw1), .rd1_out(ex_rd1)
    );

    // --- STAGE D: MEMORY / WRITEBACK ---
    memory_wb_stage u_mem_wb (
        .clk(clk), .reset(reset),
        .alu_res0(ex_res0), .wdata0(ex_wdata0), 
        .mem_read0(ex_mr0), .mem_write0(ex_mw0), .reg_write0(ex_rw0), .rd0(ex_rd0),
        .alu_res1(ex_res1), .wdata1(ex_wdata1),
        .mem_read1(ex_mr1), .mem_write1(ex_mw1), .reg_write1(ex_rw1), .rd1(ex_rd1),
        .wb_data0(wb_data0), .wb_rd0(wb_rd0), .wb_en0(wb_en0),
        .wb_data1(wb_data1), .wb_rd1(wb_rd1), .wb_en1(wb_en1)
    );

    // 3. DECODER TASK

    task decode_instruction;
        input  [31:0] instr;
        output [3:0]  alu_op;
        output        mem_read;
        output        mem_write;
        output        reg_write;
        output        use_imm;
        output [31:0] imm;
        
        reg [6:0] opcode;
        reg [2:0] funct3;
        reg [6:0] funct7;
        
        begin
            opcode = instr[6:0];
            funct3 = instr[14:12];
            funct7 = instr[31:25];
            alu_op    = 4'b0000; mem_read  = 0; mem_write = 0; reg_write = 0; use_imm   = 0; imm = 0;

            case (opcode)
                7'b0110011: begin // R-Type
                    reg_write = 1;
                    if (funct3 == 3'b000) alu_op = (funct7 == 0) ? 4'b0000 : 4'b0001;
                    else if (funct3 == 3'b110) alu_op = 4'b0011;
                    else if (funct3 == 3'b111) alu_op = 4'b0010;
                    else if (funct3 == 3'b001) alu_op = 4'b0101;
                end
                7'b0010011: begin // I-Type
                    reg_write = 1; use_imm = 1; imm = {{20{instr[31]}}, instr[31:20]};
                    if (funct3 == 3'b000) alu_op = 4'b0000;
                    else if (funct3 == 3'b110) alu_op = 4'b0011;
                end
                7'b0000011: begin // LW
                    reg_write = 1; mem_read = 1; use_imm = 1; imm = {{20{instr[31]}}, instr[31:20]};
                end
                7'b0100011: begin // SW
                    mem_write = 1; use_imm = 1; imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                end
            endcase
        end
    endtask

endmodule