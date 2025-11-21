
// Module: SCOREBOARD

// The "Scoreboard" is the traffic cop of the CPU. 
// It prevents crashes (hazards) by stopping instructions if the data they need is not ready yet.


module scoreboard (
  
    // 1. SYSTEM INPUTS
    // "input wire": A signal coming INTO this module.
    // "clk"
    // "rst": Reset signal to clear everything to 0.
    input wire clk,
    input wire rst,

    // 2. INSTRUCTION 1 INPUTS (First instruction in the pair)
  
    // "[4:0]": A bus of 5 wires. We need 5 bits to address 32 registers (2^5 = 32).
    input wire [4:0] inst1_dest,   // Destination: Where Inst 1 writes data (rd)
    input wire [4:0] inst1_src1,   // Source 1: First ingredient for Inst 1 (rs1)
    input wire [4:0] inst1_src2,   // Source 2: Second ingredient for Inst 1 (rs2)
    input wire       inst1_write_en, // 1 if this instruction writes to a register


    // 3. INSTRUCTION 2 INPUTS (Second instruction in the pair)
  
    input wire [4:0] inst2_dest,   // Destination for Inst 2
    input wire [4:0] inst2_src1,   // Source 1 for Inst 2
    input wire [4:0] inst2_src2,   // Source 2 for Inst 2
    input wire       inst2_write_en, // 1 if Inst 2 writes to a register

   
    // 4. WRITE-BACK INPUTS (Feedback from the end of pipeline)

    // When an instruction finishes, it tells the scoreboard here.
    input wire [4:0] wb_dest1,     // Address of register just updated by pipeline slot 0
    input wire       wb_valid1,    // 1 if write-back actually happened
    
    input wire [4:0] wb_dest2,     // Address of register just updated by pipeline slot 1
    input wire       wb_valid2,    // 1 if write-back actually happened

   
    // 5. CONTROL OUTPUTS (Commands to the Fetch/Decode units)
  
    // "output reg": A signal going OUT that holds its value (like a memory).
    output reg stall_fetch,   // 1 = Tell Fetch unit to stop grabbing new code
    output reg stall_decode,  // 1 = Tell Decode unit to freeze
    output reg flush_decode   // 1 = Clear the pipeline (not heavily used here)
);

    
    // INTERNAL DATA STORAGE

    // "reg busy_table [0:31]": An array of 32 registers, 1 bit each.
    // If busy_table[5] is 1, it means Register 5 is currently being used.
    reg busy_table [0:31]; 
    
    // "integer": A variable used for 'for loops' (like 'int i' in C).
    integer i;


    // HAZARD DETECTION LOGIC (Continuous Checking)

    // "wire": A connecting wire. It updates instantly when inputs change.
    // "&&": Logical AND.
    // "||": Logical OR.
    // "!=": Not Equal.
    
    // CHECK 1: Does Instruction 1 need a register that is busy?
    // We only care if src != 0 because Register 0 is always 0 (never busy).
    wire hazard_inst1 = (busy_table[inst1_src1] && inst1_src1 != 0) || 
                        (busy_table[inst1_src2] && inst1_src2 != 0);

    // CHECK 2: Does Instruction 2 need a register that is busy?
    wire hazard_inst2 = (busy_table[inst2_src1] && inst2_src1 != 0) || 
                        (busy_table[inst2_src2] && inst2_src2 != 0);

    // CHECK 3: Write-After-Write (WAW) Hazard
    // Are both instructions trying to write to the SAME register at the SAME time?
    wire hazard_waw = (inst1_write_en && inst2_write_en) && 
                      (inst1_dest == inst2_dest) && 
                      (inst1_dest != 0);

    // STALL LOGIC BLOCK

    // "always @(*)": This block runs anytime ANY input signal changes.
    // It acts like combinational logic gates.
    always @(*) begin
        // Default state: No stalling.
        stall_fetch = 0; 
        stall_decode = 0; 
        flush_decode = 0;

        // If any hazard is detected...
        if (hazard_inst1 || hazard_inst2) begin
            stall_decode = 1; // Freeze Decode stage
            stall_fetch = 1;  // Freeze Fetch stage
        end

        if (hazard_waw) begin
             stall_decode = 1; 
             stall_fetch = 1;
        end
    end

   
    // BUSY TABLE UPDATE BLOCK (Clocked Logic)
  
    // "always @(posedge clk)": This block ONLY runs when the clock goes from 0 to 1.
    // This is how we update state/memory in the CPU.
    always @(posedge clk or posedge rst) begin
        
        // 1. RESET CONDITION
        if (rst) begin
            // Loop through all 32 registers and set busy to 0 (Not Busy)
            for (i = 0; i < 32; i = i + 1) busy_table[i] <= 0;
        end 
        
        // 2. NORMAL OPERATION
        else begin
            // --- STEP A: CLEAR BUSY BITS (Instruction Finished) ---
            // If Write-Back signals are valid, the data is ready. Free the register.
            
            if (wb_valid1 && wb_dest1 != 0) begin
                 busy_table[wb_dest1] <= 0; // Mark as "Free"
                 // "$display": Prints text to your simulation terminal (like printf).
                 $display("[SCOREBOARD] Time=%0t | Clearing Busy[%d]", $time, wb_dest1);
            end
            if (wb_valid2 && wb_dest2 != 0) begin
                 busy_table[wb_dest2] <= 0; // Mark as "Free"
                 $display("[SCOREBOARD] Time=%0t | Clearing Busy[%d]", $time, wb_dest2);
            end

            // --- STEP B: SET BUSY BITS (Instruction Starting) ---
            // Only issue new instructions if we are NOT stalled.
            if (!stall_decode) begin
                
                // If Inst 1 writes to a register, mark it BUSY so others wait.
                if (inst1_write_en && inst1_dest != 0) begin
                     busy_table[inst1_dest] <= 1; // Mark as "Busy"
                     $display("[SCOREBOARD] Time=%0t | Setting Busy[%d]", $time, inst1_dest);
                end
                
                // If Inst 2 writes to a register, mark it BUSY.
                if (inst2_write_en && inst2_dest != 0) begin
                     busy_table[inst2_dest] <= 1; // Mark as "Busy"
                     $display("[SCOREBOARD] Time=%0t | Setting Busy[%d]", $time, inst2_dest);
                end

            end else begin
                // --- STEP C: DEBUGGING STALLS ---
                // If we ARE stalled, print why.
                if (hazard_inst1) 
                    $display("[SCOREBOARD] Time=%0t | STALL: Slot 1 waiting for Reg %d or %d", $time, inst1_src1, inst1_src2);
                if (hazard_inst2) 
                    $display("[SCOREBOARD] Time=%0t | STALL: Slot 2 waiting for Reg %d or %d", $time, inst2_src1, inst2_src2);
            end
        end
    end

endmodule