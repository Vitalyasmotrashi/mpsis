module led_sb_ctrl #(
  parameter int unsigned BLINK_HALF_PERIOD = 10_000_000
) (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        req_i,
  input  logic        write_enable_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  output logic [31:0] read_data_o,

  output logic [15:0] led_o
);

  localparam logic [23:0] LED_VALUE_ADDR = 24'h000000;
  localparam logic [23:0] LED_MODE_ADDR  = 24'h000004;
  localparam logic [23:0] RESET_ADDR     = 24'h000024;

  logic [15:0] led_val;
  logic        led_mode;
  logic [31:0] blink_counter;
  logic        soft_reset;

  assign soft_reset = req_i && write_enable_i &&
                      addr_i[23:0] == RESET_ADDR &&
                      write_data_i == 32'd1;

  assign led_o = led_mode
               ? ((blink_counter < BLINK_HALF_PERIOD) ? led_val : 16'd0)
               : led_val;

  always_ff @(posedge clk_i) begin
    if (rst_i || soft_reset) begin
      led_val       <= 16'd0;
      led_mode      <= 1'b0;
      blink_counter <= 32'd0;
      read_data_o   <= 32'd0;
    end else begin
      if (led_mode) begin
        if (blink_counter == (2 * BLINK_HALF_PERIOD - 1)) begin
          blink_counter <= 32'd0;
        end else begin
          blink_counter <= blink_counter + 32'd1;
        end
      end else begin
        blink_counter <= 32'd0;
      end

      if (req_i && write_enable_i) begin
        case (addr_i[23:0])
          LED_VALUE_ADDR: led_val  <= write_data_i[15:0];
          LED_MODE_ADDR:  led_mode <= write_data_i[0];
          default: begin
          end
        endcase
      end

      if (req_i && !write_enable_i) begin
        case (addr_i[23:0])
          LED_VALUE_ADDR: read_data_o <= {16'd0, led_val};
          LED_MODE_ADDR:  read_data_o <= {31'd0, led_mode};
          default: begin
          end
        endcase
      end
    end
  end

endmodule
