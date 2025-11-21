
// Helper Module: 4-Read, 2-Write Register File

module reg_file_4r2w (
    input clk,
    input rst,

    // Read Ports (Combinational)
    input  [4:0] raddr0_1, output [31:0] rdata0_1,
    input  [4:0] raddr0_2, output [31:0] rdata0_2,
    input  [4:0] raddr1_1, output [31:0] rdata1_1,
    input  [4:0] raddr1_2, output [31:0] rdata1_2,

    // Write Ports (Clocked)
    input  [4:0] waddr0, input [31:0] wdata0, input wen0,
    input  [4:0] waddr1, input [31:0] wdata1, input wen1
);

    reg [31:0] regs [0:31];
    integer i;

    // Writes
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) regs[i] <= 0;
        end else begin
            // Priority: If both write to same addr, Port 1 wins (later instruction)
            if (wen0 && waddr0 != 0) regs[waddr0] <= wdata0;
            if (wen1 && waddr1 != 0) regs[waddr1] <= wdata1;
        end
    end

    // Reads (x0 is always 0)
    assign rdata0_1 = (raddr0_1 == 0) ? 0 : regs[raddr0_1];
    assign rdata0_2 = (raddr0_2 == 0) ? 0 : regs[raddr0_2];
    assign rdata1_1 = (raddr1_1 == 0) ? 0 : regs[raddr1_1];
    assign rdata1_2 = (raddr1_2 == 0) ? 0 : regs[raddr1_2];

endmodule