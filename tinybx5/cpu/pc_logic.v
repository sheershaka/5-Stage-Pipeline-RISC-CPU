module pc_logic(
    input           clk,
    input           nreset,
    input [31:0]    inst,
    input [31:0]    rf_d2,
    input           rf_we1,
    input [3:0]     rf_ws1,
    input [31:0]    rf_wd1,
    input           rf_we2,
    input [3:0]     rf_ws2,
    input [31:0]    rf_wd2,
    input           cond_go,
    input           do_update,
    output          branch_taken,
    output     [31:0] pc,
    output reg [31:0] pc_plus4);

`include "arm32_base.v"

  
  reg [31:0] the_pc;
  reg [31:0] next_pc;
  reg [31:0] branch_target;
  assign pc = the_pc;

  always @(*) begin
    pc_plus4 = the_pc + 4;
    if (inst_type(inst) == inst_type_branch_and_exchange)
      branch_target = rf_d2;
    else
      branch_target = the_pc + inst_branch_imm(inst);

    branch_taken = true;
    if (rf_we1 && rf_ws1 == r15)  // WB stage has a write to r15
      next_pc = rf_wd1;
    else
    if (rf_we2 && rf_ws2 == r15)  // WB stage has a write to r15
      next_pc = rf_wd2;
    else
    if ((inst_type(inst) == inst_type_branch ||
        inst_type(inst) == inst_type_branch_and_link ||
        inst_type(inst) == inst_type_branch_and_exchange) && cond_go)
      next_pc = branch_target;
    else begin
      next_pc = pc_plus4;
      branch_taken = false;
    end
  end

  always @(posedge clk) begin
    if (!nreset) begin
        the_pc <= 32'd0;
    end
    else begin
      if (do_update)
        the_pc <= next_pc;
    end
  end

endmodule