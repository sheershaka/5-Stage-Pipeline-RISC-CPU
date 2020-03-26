module cpu(
  input wire clk,
  input wire nreset,
  output wire led,
  output wire [7:0] debug_port1,
  output wire [7:0] debug_port2,
  output wire [7:0] debug_port3,
  output wire [7:0] debug_port4,
  output wire [7:0] debug_port5,
  output wire [7:0] debug_port6,
  output wire [7:0] debug_port7
  );
`include "arm32_base.v"

  assign led = led_debug;
  assign debug_port1 = pc[7:0];
  assign debug_port2 = { zero, debug_phase, fetch_flush, decode_flush, exec_flush, mem_flush };
  assign debug_port3 = { fetch_valid, decode_valid, exec_valid, mem_valid,
                         fetch_advance, decode_advance, exec_advance, mem_advance };

  assign debug_port4 = debug_word[31:24];
  assign debug_port5 = debug_word[23:16];
  assign debug_port6 = debug_word[15:8];
  assign debug_port7 = debug_word[7:0];

  reg [31:0] debug_word = { program_debug, alu_result[23:0] };

  // one byte of output to send to the debugger programmically.  This is a register.
  reg [7:0] program_debug;

  // LED we also expose to the program for setting.
  reg       led_debug;


  // Valid, flush and stall signals for the stages ("global" to the processor)
  reg   fetch_valid;
  reg   fetch_flush;
  reg   decode_valid;
  reg   decode_flush;
  reg   exec_valid;
  reg   exec_flush;
  reg   mem_valid;
  reg   mem_flush;
  reg   fetch_advance;
  reg   decode_advance;
  reg   exec_advance;
  reg   mem_advance;

  // "Backward edges"
  // For branching
  reg [31:0]    decode_inst;
  reg [31:0]    rf_d2;
  wire          cond_go;

  // Backward edges for write back
  reg [31:0]    rf_wd1;
  reg [31:0]    rf_wd2;
  reg           wb_phase;
  reg   [3:0]   mem_rf_ws1;
  reg   [3:0]   mem_rf_ws2;
  reg           mem_rf_we1;
  reg           mem_rf_we2;

//  "Fetch" from code memory into instruction bits 
  wire [31:0] pc;
  reg [31:0]  fetch_inst;
  fetch the_instruction_memory( .clk(clk),
                                .do_fetch(fetch_advance),
                                .pc(pc),
                                .inst(fetch_inst));


  reg branch_taken;
  wire [31:0] pc_plus4;
  pc_logic the_pc_logic(.clk(clk),
                        .nreset(nreset),
                        .inst(decode_inst),
                        .rf_d2(rf_d2),
                        .rf_we1(mem_valid && mem_rf_we1),
                        .rf_ws1(mem_rf_ws1),
                        .rf_wd1(rf_wd1),
                        .rf_we2(mem_valid && mem_rf_we2),
                        .rf_ws2(mem_rf_ws2),
                        .rf_wd2(rf_wd2),
                        .cond_go(cond_go && decode_valid),
                        .do_update(fetch_advance),
                        .branch_taken(branch_taken),
                        .pc(pc),
                        .pc_plus4(pc_plus4));

  always @(posedge clk) begin
    if (!nreset || fetch_flush)
      fetch_valid <= false;
    else
      fetch_valid <= true;
  end

  // Decode what gets read and written from the register file
  wire [3:0] rf_rs1;
  wire [3:0] rf_rs2;
  wire [3:0] rf_rs3;
  wire [3:0] rf_ws1;
  wire [3:0] rf_ws2;
  wire rf_we1;
  wire rf_we2;
  reg_decode the_reg_decode(.inst(fetch_inst),
                            .rf_rs1(rf_rs1),
                            .rf_rs2(rf_rs2),
                            .rf_rs3(rf_rs3),
                            .rf_ws1(rf_ws1),
                            .rf_ws2(rf_ws2),
                            .rf_we1(rf_we1),
                            .rf_we2(rf_we2));

  // The actual register file proper
  wire   [31:0]  decode_rf_d1;
  wire   [31:0]  decode_rf_d2;
  wire   [31:0]  decode_rf_d3;
  wire   [31:0]  decode_rf_d1_raw;
  wire   [31:0]  decode_rf_d2_raw;
  wire   [31:0]  decode_rf_d3_raw;
  wire   [31:0]  last_write;
  wire   [3:0]   last_write_ws;
  wire           last_write_valid;
  reg_file the_reg_file(.clk(clk),
                        .rf_rs1(rf_rs1),
                        .rf_rs2(rf_rs2),
                        .rf_rs3(rf_rs3),
                        .rf_ws1(mem_rf_ws1),
                        .rf_ws2(mem_rf_ws2),
                        .rf_wd1(rf_wd1),
                        .rf_wd2(rf_wd2),
                        .rf_we1(mem_rf_we1),
                        .rf_we2(mem_rf_we2),
                        .do_read(true),
                        .do_write1(mem_valid && wb_phase == zero),
                        .do_write2(mem_valid && wb_phase == one),
                        .rf_d1(decode_rf_d1_raw),
                        .rf_d2(decode_rf_d2_raw),
                        .rf_d3(decode_rf_d3_raw),
                        .last_write(last_write),
                        .last_write_ws(last_write_ws),
                        .last_write_valid(last_write_valid)
                        );
  // Bypass "through" the register file (done here instead of negedge writes)
  assign decode_rf_d1 = (last_write_valid && decode_rf_rs1 == last_write_ws) ? last_write : decode_rf_d1_raw;
  assign decode_rf_d2 = (last_write_valid && decode_rf_rs2 == last_write_ws) ? last_write : decode_rf_d2_raw;
  assign decode_rf_d3 = (last_write_valid && decode_rf_rs3 == last_write_ws) ? last_write : decode_rf_d3_raw;

  reg   [3:0]   decode_rf_rs1;
  reg   [3:0]   decode_rf_rs2;
  reg   [3:0]   decode_rf_rs3;
  reg   [3:0]   decode_rf_ws1;
  reg   [3:0]   decode_rf_ws2;
  reg           decode_rf_we1;
  reg           decode_rf_we2;
  reg   [31:0]  decode_pc_plus4;
  always @(posedge clk) begin
    if (!nreset || decode_flush)
      decode_valid <= false;
    else begin
      if (decode_advance) begin
        decode_inst <= fetch_inst;
        decode_valid <= fetch_valid;
        decode_rf_rs1 <= rf_rs1;
        decode_rf_rs2 <= rf_rs2;
        decode_rf_rs3 <= rf_rs3;
        decode_rf_ws1 <= rf_ws1;
        decode_rf_ws2 <= rf_ws2;
        decode_rf_we1 <= rf_we1;
        decode_rf_we2 <= rf_we2;
        decode_pc_plus4 <= pc;
      end
    end
  end

  reg [31:0] from_decode_rf_d1;
  reg [31:0] from_decode_rf_d2;
  reg [31:0] from_decode_rf_d3;
  reg [31:0] from_wb_and_decode_rf_d1;
  reg [31:0] from_wb_and_decode_rf_d2;
  reg [31:0] from_wb_and_decode_rf_d3;
  reg [31:0] rf_d1;
  reg [31:0] rf_d3;
  always @(*) begin
    // Patch the result from decode to put in the PC
    from_decode_rf_d1 = (decode_rf_rs1 == r15) ?
      ((inst_type(decode_inst) == inst_type_data_proc && shift_source(decode_inst) == shift_reg) ? 
      (pc_plus4) : pc) : decode_rf_d1;
    from_decode_rf_d2 = (decode_rf_rs2 == r15) ?
      ((inst_type(exec_inst) == inst_type_data_proc && shift_source(decode_inst) == shift_reg) ? 
      (pc_plus4) : pc) : decode_rf_d2;
    from_decode_rf_d3 = (decode_rf_rs3 == r15) ?
      (((inst_type(decode_inst) == inst_type_data_proc && shift_source(decode_inst) == shift_reg) ||
       (inst_type(decode_inst) == inst_type_sdt && inst_sdt_load(decode_inst) == sdt_is_store)) ?
      (pc_plus4) : pc) : decode_rf_d3;

    // By pass from write back stage
    if (mem_valid) begin
      from_wb_and_decode_rf_d1 = (mem_rf_we1 && mem_rf_ws1 == decode_rf_rs1) ? rf_wd1 :
                                 (mem_rf_we2 && mem_rf_ws2 == decode_rf_rs1) ? rf_wd2 :
                                       from_decode_rf_d1;
      from_wb_and_decode_rf_d2 = (mem_rf_we1 && mem_rf_ws1 == decode_rf_rs2) ? rf_wd1 :
                                 (mem_rf_we2 && mem_rf_ws2 == decode_rf_rs2) ? rf_wd2 :
                                       from_decode_rf_d2;
      from_wb_and_decode_rf_d3 = (mem_rf_we1 && mem_rf_ws1 == decode_rf_rs3) ? rf_wd1 :
                                 (mem_rf_we2 && mem_rf_ws2 == decode_rf_rs3) ? rf_wd2 :
                                       from_decode_rf_d3;
    end else begin
      from_wb_and_decode_rf_d1 = from_decode_rf_d1;
      from_wb_and_decode_rf_d2 = from_decode_rf_d2;
      from_wb_and_decode_rf_d3 = from_decode_rf_d3;
    end

    // By pass from mem stage.
    // Subtle: we don't check if it's a load -> use dependence because the stalling will take care of that
    if (exec_valid) begin
      rf_d1 = (exec_rf_we1 && exec_rf_ws1 == decode_rf_rs1) ? exec_alu_result[31:0] :
              (exec_rf_we2 && exec_rf_ws2 == decode_rf_rs1) ? exec_adder_result[31:0] :
                                       from_wb_and_decode_rf_d1;
      rf_d2 = (exec_rf_we1 && exec_rf_ws1 == decode_rf_rs2) ? exec_alu_result[31:0] :
              (exec_rf_we2 && exec_rf_ws2 == decode_rf_rs2) ? exec_adder_result[31:0] :
                                       from_wb_and_decode_rf_d2;
      rf_d3 = (exec_rf_we1 && exec_rf_ws1 == decode_rf_rs3) ? exec_alu_result[31:0] :
              (exec_rf_we2 && exec_rf_ws2 == decode_rf_rs3) ? exec_adder_result[31:0] :
                                       from_wb_and_decode_rf_d3;
    end else begin
      rf_d1 = from_wb_and_decode_rf_d1;
      rf_d2 = from_wb_and_decode_rf_d2;
      rf_d3 = from_wb_and_decode_rf_d3;
    end


  end  

  // Decode the condition in the instruction relative to the flags
  reg   [31:0]  cpsr;
  wire  [31:0]  next_cpsr;
  wire          set_cond_bits;
  flag_compute the_flag_compute(.inst(decode_inst),
                                .cpsr(cpsr),
                                .cond_go(cond_go),
                                .set_cond_bits(set_cond_bits));


  wire [32:0] shifter_output;
  wire carry_from_shift;
  shifter the_shifter(.inst(decode_inst),
                      .register_input(rf_d2),
                      .shift_register_input(rf_d3),
                      .in_cpsr_c(cpsr[cpsr_c]),
                      .shifter_output(shifter_output),
                      .carry_from_shift(carry_from_shift));

  wire [32:0] alu_result;
  wire [32:0] adder_result;
  alu the_alu(.inst(decode_inst),
              .operand1({ zero, rf_d1 }),
              .operand2(shifter_output),
              .cpsr(cpsr),
              .carry_from_shift(carry_from_shift),
              .result(alu_result),
              .next_cpsr(next_cpsr),
              .adder_result(adder_result));

  always @(posedge clk) begin 
    if (decode_valid && exec_advance && set_cond_bits) begin
      cpsr[cpsr_c] <= next_cpsr[cpsr_c];
      cpsr[cpsr_n] <= next_cpsr[cpsr_n];
      cpsr[cpsr_z] <= next_cpsr[cpsr_z];
      cpsr[cpsr_v] <= next_cpsr[cpsr_v];
    end
    cpsr[27:0] <= 28'd0;  // most of the cpsr we don't support
  end

  reg   [31:0]  exec_inst;
  reg   [31:0]  exec_rf_d1;
  reg   [31:0]  exec_rf_d3;
  reg   [3:0]   exec_rf_ws1;
  reg   [3:0]   exec_rf_ws2;
  reg           exec_rf_we1;
  reg           exec_rf_we2;
  reg   [32:0]  exec_adder_result;
  reg   [32:0]  exec_alu_result;
  always @(posedge clk) begin
    if (!nreset || exec_flush)
      exec_valid <= false;
    else begin
      if (exec_advance) begin
        exec_inst <= decode_inst;
        exec_valid <= decode_valid && cond_go;
        exec_rf_d1 <= rf_d1;
        exec_rf_d3 <= rf_d3;
        exec_rf_ws1 <= decode_rf_ws1;
        exec_rf_ws2 <= decode_rf_ws2;
        exec_rf_we1 <= decode_rf_we1;
        exec_rf_we2 <= decode_rf_we2;
        exec_adder_result <= adder_result;
        exec_alu_result <= (inst_type(decode_inst) == inst_type_branch_and_link) ?
                           {zero, decode_pc_plus4 } : alu_result;
      end
    end
  end

  wire [31:0]   mem_addr;
  wire [31:0]   mem_write_data;
  wire [3:0]    mem_we;
  wire          mem_re;
  wire          is_mmio_raw;
  wire          is_mmio;
  mem_pre_decode  the_mem_pre_decode(
    .inst(exec_inst),
    .cond_go(exec_valid),
    .adder_result(exec_adder_result[31:0]),
    .base_reg(exec_rf_d1),
    .rf_data(exec_rf_d3),
    .mem_addr(mem_addr),
    .mem_write_data(mem_write_data),
    .mem_write_enable(mem_we),
    .mem_read_enable(mem_re),
    .is_mmio(is_mmio_raw));
  assign is_mmio = is_mmio_raw && (exec_valid && mem_advance) && inst_type(exec_inst) == inst_type_sdt;

  wire  [31:0]  mem_read_data;
  mem the_mem(
    .clk(clk),
    .mem_addr(mem_addr),
    .do_read((exec_valid && mem_advance) ? mem_re : false),
    .do_write_byte((exec_valid && mem_advance) ? mem_we : 4'd0),
    .mem_write_data(mem_write_data),
    .mem_read_data(mem_read_data));

  reg   [31:0]  mem_inst;
  reg   [32:0]  mem_adder_result;
  reg   [32:0]  mem_alu_result;
  reg   [31:0]  mem_addr_wb;
  always @(posedge clk) begin
    if (!nreset || mem_flush)
      mem_valid <= false;
    else begin
      if (mem_advance) begin
        mem_inst <= exec_inst;
        mem_valid <= exec_valid;
        mem_adder_result <= exec_adder_result;
        mem_alu_result <= exec_alu_result;
        mem_addr_wb <= mem_addr;
        mem_rf_ws1 <= exec_rf_ws1;
        mem_rf_ws2 <= exec_rf_ws2;
        mem_rf_we1 <= exec_rf_we1;
        mem_rf_we2 <= exec_rf_we2;
      end
    end
  end

  // This is actually in the write back stage, even though it's it's part of mem.
  // Memory is synchronous, so have to do it here.
  wire [31:0] mem_load_data;
  mem_post_decode the_mem_post_decode(
    .inst(mem_inst),
    .mem_addr(mem_addr_wb),
    .mem_read_data(mem_read_data),
    .mem_data_load(mem_load_data));

  // I/O.  Well output for now at least.  This lets executed ARM code
  // talk to one of the debug Verilog ports.
  always @(posedge clk) begin
    if (is_mmio &&
        inst_sdt_load(exec_inst) == sdt_is_store) begin
      case (mem_addr[15:0])
        // Send the byte to the debugger
        16'h0000: program_debug <= mem_write_data[7:0];
        // Set the LED
        16'h0010: led_debug <= mem_write_data[0];
        default: begin end
      endcase
    end
  end
  
  // Figure out what is written to the register file
  always @(*) begin
    rf_wd1 = (inst_type(mem_inst) == inst_type_sdt && inst_sdt_load(mem_inst) == sdt_is_load) ?
              (mem_load_data) :
              mem_alu_result[31:0]; 
    rf_wd2 = mem_adder_result[31:0];
  end

  always @(posedge clk) begin
    if (!nreset)
      wb_phase <= zero;
    else begin
      if (mem_valid && wb_phase == zero && mem_rf_we2)
        wb_phase <= one;
      else
        wb_phase <= zero;
    end
  end

  // Compute stalls & flushes
  always @(*) begin
    fetch_advance = true;
    decode_advance = true;
    exec_advance = true;
    mem_advance = true;
    mem_flush = false;
    exec_flush = false;
    decode_flush = false;
    fetch_flush = false;

    if (mem_valid && wb_phase == zero && mem_rf_we2) begin // Stall everything on base address write back
      fetch_advance = false;
      decode_advance = false;
      exec_advance = false;
      mem_advance = false;
    end else if (decode_valid && exec_valid && mem_re && exec_rf_we1) begin // Stall if we are loading a reg that is used
      if (decode_rf_rs1 == exec_rf_ws1 ||
          decode_rf_rs2 == exec_rf_ws1 ||
          decode_rf_rs3 == exec_rf_ws1) begin
        // Note this does not fast path LOAD followed immediately by a STORE, which actually could be done
        fetch_advance = false;
        decode_advance = false;
        exec_flush = true;  // insert a bubble.
      end
    end

    // Flush when we write to r15 in the first writeback stage
    if (mem_valid && mem_rf_we1 && mem_rf_ws1 == r15 && wb_phase == zero) begin
      exec_flush = true;
      decode_flush = true;
      fetch_flush = true;
    end
    // Flush when write to r15 in the second wb phase
    if (mem_valid && mem_rf_we2 && mem_rf_ws2 == r15 && wb_phase == one) begin
      exec_flush = true;
      decode_flush = true;
      fetch_flush = true;
    end
    // Flush when a branch is taken
    if (decode_valid && cond_go && branch_taken) begin
      fetch_flush = true;
      decode_flush = true;
    end

  end

endmodule
