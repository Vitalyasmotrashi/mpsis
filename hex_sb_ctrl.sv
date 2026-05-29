module hex_sb_ctrl (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] addr_i,
  input  logic        req_i,
  input  logic [31:0] write_data_i,
  input  logic        write_enable_i,
  output logic [31:0] read_data_o,

  output logic [6:0]  hex_led_o,
  output logic [7:0]  hex_sel_o
);

  localparam logic [23:0] BITMASK_ADDR = 24'h000020;
  localparam logic [23:0] RESET_ADDR   = 24'h000024;

  logic [3:0] hex [8];
  logic [7:0] bitmask;
  logic       soft_reset;

  assign soft_reset = req_i && write_enable_i &&
                      addr_i[23:0] == RESET_ADDR &&
                      write_data_i == 32'd1;

  hex_digits hex_digits_inst (
    .clk_i     (clk_i),
    .rst_i     (rst_i || soft_reset),
    .hex0_i    (hex[0]),
    .hex1_i    (hex[1]),
    .hex2_i    (hex[2]),
    .hex3_i    (hex[3]),
    .hex4_i    (hex[4]),
    .hex5_i    (hex[5]),
    .hex6_i    (hex[6]),
    .hex7_i    (hex[7]),
    .bitmask_i (bitmask),
    .hex_led_o (hex_led_o),
    .hex_sel_o (hex_sel_o)
  );

  always_ff @(posedge clk_i) begin
    if (rst_i || soft_reset) begin
      for (int i = 0; i < 8; i++) begin
        hex[i] <= 4'd0;
      end
      bitmask     <= 8'hff;
      read_data_o <= 32'd0;
    end else begin
      if (req_i && write_enable_i) begin
        if (addr_i[23:0] <= 24'h00001c && addr_i[1:0] == 2'b00) begin
          hex[addr_i[4:2]] <= write_data_i[3:0];
        end else if (addr_i[23:0] == BITMASK_ADDR) begin
          bitmask <= write_data_i[7:0];
        end
      end

      if (req_i && !write_enable_i) begin
        if (addr_i[23:0] <= 24'h00001c && addr_i[1:0] == 2'b00) begin
          read_data_o <= {28'd0, hex[addr_i[4:2]]};
        end else if (addr_i[23:0] == BITMASK_ADDR) begin
          read_data_o <= {24'd0, bitmask};
        end
      end
    end
  end

endmodule
