module uart_rx_sb_ctrl (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] addr_i,
  input  logic        req_i,
  input  logic [31:0] write_data_i,
  input  logic        write_enable_i,
  output logic [31:0] read_data_o,

  output logic        interrupt_request_o,
  input  logic        interrupt_return_i,

  input  logic        rx_i
);

  localparam logic [23:0] DATA_ADDR     = 24'h000000;
  localparam logic [23:0] VALID_ADDR    = 24'h000004;
  localparam logic [23:0] BUSY_ADDR     = 24'h000008;
  localparam logic [23:0] BAUDRATE_ADDR = 24'h00000c;
  localparam logic [23:0] PARITY_ADDR   = 24'h000010;
  localparam logic [23:0] STOPBIT_ADDR  = 24'h000014;
  localparam logic [23:0] RESET_ADDR    = 24'h000024;

  logic       busy;
  logic       busy_wire;
  logic [16:0] baudrate;
  logic       parity_en;
  logic [1:0] stopbit;
  logic [7:0] data;
  logic       valid;
  logic [7:0] rx_data;
  logic       rx_valid;
  logic       soft_reset;
  logic       read_data_req;

  assign interrupt_request_o = valid;
  assign soft_reset          = req_i && write_enable_i &&
                               addr_i[23:0] == RESET_ADDR &&
                               write_data_i == 32'd1;
  assign read_data_req       = req_i && !write_enable_i && addr_i[23:0] == DATA_ADDR;

  uart_rx rx_inst (
    .clk_i       (clk_i),
    .rst_i       (rst_i || soft_reset),
    .rx_i        (rx_i),
    .busy_o      (busy_wire),
    .baudrate_i  (baudrate),
    .parity_en_i (parity_en),
    .stopbit_i   (stopbit),
    .rx_data_o   (rx_data),
    .rx_valid_o  (rx_valid)
  );

  always_ff @(posedge clk_i) begin
    if (rst_i || soft_reset) begin
      busy        <= 1'b0;
      baudrate    <= 17'd9600;
      parity_en   <= 1'b0;
      stopbit     <= 2'd1;
      data        <= 8'd0;
      valid       <= 1'b0;
      read_data_o <= 32'd0;
    end else begin
      busy <= busy_wire;

      if (rx_valid) begin
        data  <= rx_data;
        valid <= 1'b1;
      end else if (read_data_req || interrupt_return_i) begin
        valid <= 1'b0;
      end

      if (req_i && write_enable_i && !busy_wire) begin
        case (addr_i[23:0])
          BAUDRATE_ADDR: baudrate  <= write_data_i[16:0];
          PARITY_ADDR:   parity_en <= write_data_i[0];
          STOPBIT_ADDR:  stopbit   <= write_data_i[1:0];
          default: begin
          end
        endcase
      end

      if (req_i && !write_enable_i) begin
        case (addr_i[23:0])
          DATA_ADDR:     read_data_o <= {24'd0, data};
          VALID_ADDR:    read_data_o <= {31'd0, valid};
          BUSY_ADDR:     read_data_o <= {31'd0, busy};
          BAUDRATE_ADDR: read_data_o <= {15'd0, baudrate};
          PARITY_ADDR:   read_data_o <= {31'd0, parity_en};
          STOPBIT_ADDR:  read_data_o <= {30'd0, stopbit};
          default: begin
          end
        endcase
      end
    end
  end

endmodule
