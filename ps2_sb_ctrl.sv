module ps2_sb_ctrl (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] addr_i,
  input  logic        req_i,
  input  logic [31:0] write_data_i,
  input  logic        write_enable_i,
  output logic [31:0] read_data_o,

  output logic        interrupt_request_o,
  input  logic        interrupt_return_i,

  input  logic        kclk_i,
  input  logic        kdata_i
);

  localparam logic [23:0] DATA_ADDR  = 24'h000000;
  localparam logic [23:0] VALID_ADDR = 24'h000004;
  localparam logic [23:0] RESET_ADDR = 24'h000024;

  logic [7:0] scan_code;
  logic       scan_code_is_unread;
  logic [7:0] keycode;
  logic       keycode_valid;
  logic       read_data_req;
  logic       soft_reset;

  assign interrupt_request_o = scan_code_is_unread;
  assign read_data_req       = req_i && !write_enable_i && addr_i[23:0] == DATA_ADDR;
  assign soft_reset          = req_i && write_enable_i &&
                               addr_i[23:0] == RESET_ADDR &&
                               write_data_i == 32'd1;

  PS2Receiver ps2_receiver (
    .clk_i           (clk_i),
    .rst_i           (rst_i || soft_reset),
    .kclk_i          (kclk_i),
    .kdata_i         (kdata_i),
    .keycode_o       (keycode),
    .keycode_valid_o (keycode_valid)
  );

  always_ff @(posedge clk_i) begin
    if (rst_i || soft_reset) begin
      scan_code             <= 8'd0;
      scan_code_is_unread   <= 1'b0;
      read_data_o           <= 32'd0;
    end else begin
      if (keycode_valid) begin
        scan_code           <= keycode;
        scan_code_is_unread <= 1'b1;
      end else if (read_data_req || interrupt_return_i) begin
        scan_code_is_unread <= 1'b0;
      end

      if (req_i && !write_enable_i) begin
        case (addr_i[23:0])
          DATA_ADDR:  read_data_o <= {24'd0, scan_code};
          VALID_ADDR: read_data_o <= {31'd0, scan_code_is_unread};
          default: begin
          end
        endcase
      end
    end
  end

endmodule
