module sw_sb_ctrl (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        req_i,
  input  logic        write_enable_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  output logic [31:0] read_data_o,

  output logic        interrupt_request_o,
  input  logic        interrupt_return_i,

  input  logic [15:0] sw_i
);

  logic [15:0] sw_prev;
  logic        interrupt_request;

  assign interrupt_request_o = interrupt_request;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      sw_prev           <= 16'd0;
      interrupt_request <= 1'b0;
      read_data_o       <= 32'd0;
    end else begin
      sw_prev <= sw_i;

      if (interrupt_return_i) begin
        interrupt_request <= 1'b0;
      end
      if (sw_i != sw_prev) begin
        interrupt_request <= 1'b1;
      end

      if (req_i && !write_enable_i && addr_i[23:0] == 24'h000000) begin
        read_data_o <= {16'd0, sw_i};
      end
    end
  end

  logic unused_write_data;
  assign unused_write_data = ^write_data_i;

endmodule
