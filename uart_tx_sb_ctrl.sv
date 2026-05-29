module uart_tx_sb_ctrl (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic [31:0] addr_i,
  input  logic        req_i,
  input  logic [31:0] write_data_i,
  input  logic        write_enable_i,
  output logic [31:0] read_data_o,

  output logic        tx_o
);

  localparam logic [23:0] DATA_ADDR     = 24'h000000;
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
  logic       soft_reset;
  logic       tx_start;

  assign soft_reset = req_i && write_enable_i &&
                      addr_i[23:0] == RESET_ADDR &&
                      write_data_i == 32'd1;
  assign tx_start   = req_i && write_enable_i &&
                      addr_i[23:0] == DATA_ADDR &&
                      !busy_wire && !(rst_i || soft_reset);

  uart_tx tx_inst (
    .clk_i       (clk_i),
    .rst_i       (rst_i || soft_reset),
    .tx_o        (tx_o),
    .busy_o      (busy_wire),
    .baudrate_i  (baudrate),
    .parity_en_i (parity_en),
    .stopbit_i   (stopbit),
    .tx_data_i   (write_data_i[7:0]),
    .tx_valid_i  (tx_start)
  );

  always_ff @(posedge clk_i) begin
    if (rst_i || soft_reset) begin
      busy        <= 1'b0;
      baudrate    <= 17'd9600;
      parity_en   <= 1'b0;
      stopbit     <= 2'd1;
      data        <= 8'd0;
      read_data_o <= 32'd0;
    end else begin
      busy <= busy_wire;

      if (req_i && write_enable_i && !busy_wire) begin
        case (addr_i[23:0])
          DATA_ADDR:     data      <= write_data_i[7:0];
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
