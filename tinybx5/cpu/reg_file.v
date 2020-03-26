module reg_file(
    input   clk,
    input   [3:0] rf_rs1,
    input   [3:0] rf_rs2,
    input   [3:0] rf_rs3,
    input   [3:0] rf_ws1,
    input   [3:0] rf_ws2,
    input   [31:0] rf_wd1,
    input   [31:0] rf_wd2,
    input   rf_we1,
    input   rf_we2,
    input   do_read,
    input   do_write1,
    input   do_write2,
    output  wire [31:0] rf_d1,
    output  wire [31:0] rf_d2,
    output  wire [31:0] rf_d3,
    output  wire [31:0] last_write,
    output  wire [3:0]  last_write_ws,
    output  wire        last_write_valid
    );

`include "arm32_base.v"

  reg [31:0]  rf[0:15];          // register 15 is the pc

  reg [31:0]  rf_d1_raw;
  reg [31:0]  rf_d2_raw;
  reg [31:0]  rf_d3_raw;
  reg [31:0]  rf_wd;
  reg [3:0]   rf_ws;
  reg read_reg_file;
  reg write_reg_file;

  // Internal bypass.  Could also clock reg file negwrite write posedge read.
  reg [31:0]  the_last_write;
  reg [3:0]   the_last_write_ws;
  reg         the_last_write_valid;
  always @(posedge clk) begin
    the_last_write <= rf_wd;
    the_last_write_ws <= rf_ws;
    the_last_write_valid <= write_reg_file && read_reg_file;
  end

  assign last_write = the_last_write;
  assign last_write_ws = the_last_write_ws;
  assign last_write_valid = the_last_write_valid;
  assign rf_d1 = rf_d1_raw;
  assign rf_d2 = rf_d2_raw;
  assign rf_d3 = rf_d3_raw;

  always @(posedge clk) begin
    if (read_reg_file) begin
      rf_d1_raw <= rf[rf_rs1];
      rf_d2_raw <= rf[rf_rs2];
      rf_d3_raw <= rf[rf_rs3];
    end
    if (write_reg_file)
      rf[rf_ws] <= rf_wd;
  end

  always @(*) begin
    read_reg_file = false;
    write_reg_file = false;

    if (do_read)
      read_reg_file = true;

    if (do_write1 && rf_we1) begin
      write_reg_file = true;
      rf_ws = rf_ws1;
      rf_wd = rf_wd1;
    end
    else if (do_write2 && rf_we2) begin
      write_reg_file = true;
      rf_ws = rf_ws2;
      rf_wd = rf_wd2;
    end else begin  // base case, just to avoid latches
      rf_ws = rf_ws1;
      rf_wd = rf_wd1;
    end
  end

  
endmodule