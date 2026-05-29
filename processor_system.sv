module processor_system (
  input  logic        clk_i,
  input  logic        resetn_i,

  // Входы и выходы периферии (присутствуют все по заданию)
  input  logic [15:0] sw_i,
  output logic [15:0] led_o,

  input  logic        kclk_i,
  input  logic        kdata_i,

  output logic [ 6:0] hex_led_o,
  output logic [ 7:0] hex_sel_o,

  input  logic        rx_i,
  output logic        tx_o,

  output logic [3:0]  vga_r_o,
  output logic [3:0]  vga_g_o,
  output logic [3:0]  vga_b_o,
  output logic        vga_hs_o,
  output logic        vga_vs_o
);

  import peripheral_pkg::*;

  logic sysclk;
  logic rst;

  // Делитель частоты
  sys_clk_rst_gen divider (
    .ex_clk_i       (clk_i),
    .ex_areset_n_i  (resetn_i),
    .div_i          (4'd5),
    .sys_clk_o      (sysclk),
    .sys_reset_o    (rst)
  );

  logic [31:0] instr_addr;
  logic [31:0] instr_data;

  logic        core_mem_req;
  logic        core_mem_we;
  logic [ 2:0] core_mem_size;
  logic [31:0] core_mem_addr;
  logic [31:0] core_mem_wd;
  logic [31:0] core_mem_rd;
  logic        core_stall;

  logic        mem_req;
  logic        mem_we;
  logic [ 3:0] mem_be;
  logic [31:0] mem_addr;
  logic [31:0] mem_wd;
  logic [31:0] mem_rd;

  logic [255:0] device_sel;
  logic         dmem_req;
  logic         dmem_ready;

  logic [31:0] dmem_rd;
  logic [31:0] led_rd;
  logic [31:0] ps2_rd;

  logic ps2_irq;
  logic irq_req;
  logic irq_ret;

  // Формирование селектора устройств
  assign device_sel = 256'b1 << mem_addr[31:24];
  
  // Запрос к памяти данных
  assign dmem_req   = mem_req && device_sel[DMEM_ADDR_HIGH];
  
  // В вашей конфигурации прерывание генерирует только PS/2
  assign irq_req    = ps2_irq;

  // Мультиплексор чтения системной шины
  always_comb begin
    case (mem_addr[31:24])
      DMEM_ADDR_HIGH: mem_rd = dmem_rd;
      LED_ADDR_HIGH:  mem_rd = led_rd;
      PS2_ADDR_HIGH:  mem_rd = ps2_rd;
      // Для всех остальных неиспользуемых устройств возвращаем нули
      default:        mem_rd = 32'd0; 
    endcase
  end

  // --- Базовые компоненты процессора ---

  instr_mem imem (
    .read_addr_i (instr_addr),
    .read_data_o (instr_data)
  );

  data_mem dmem (
    .clk_i          (sysclk),
    .mem_req_i      (dmem_req),
    .write_enable_i (mem_we),
    .byte_enable_i  (mem_be),
    .addr_i         (mem_addr),
    .write_data_i   (mem_wd),
    .read_data_o    (dmem_rd),
    .ready_o        (dmem_ready)
  );

  lsu lsu_inst (
    .clk_i        (sysclk),
    .rst_i        (rst),
    .core_req_i   (core_mem_req),
    .core_we_i    (core_mem_we),
    .core_size_i  (core_mem_size),
    .core_addr_i  (core_mem_addr),
    .core_wd_i    (core_mem_wd),
    .core_rd_o    (core_mem_rd),
    .core_stall_o (core_stall),
    .mem_req_o    (mem_req),
    .mem_we_o     (mem_we),
    .mem_be_o     (mem_be),
    .mem_addr_o   (mem_addr),
    .mem_wd_o     (mem_wd),
    .mem_rd_i     (mem_rd),
    .mem_ready_i  (1'b1)
  );

  processor_core core (
    .clk_i        (sysclk),
    .rst_i        (rst),
    .instr_addr_o (instr_addr),
    .instr_i      (instr_data),
    .mem_addr_o   (core_mem_addr),
    .mem_size_o   (core_mem_size),
    .mem_req_o    (core_mem_req),
    .mem_we_o     (core_mem_we),
    .mem_wd_o     (core_mem_wd),
    .mem_rd_i     (core_mem_rd),
    .stall_i      (core_stall),
    .irq_req_i    (irq_req),
    .irq_ret_o    (irq_ret)
  );

  // --- Периферия варианта "LED + PS/2" ---

  led_sb_ctrl led_ctrl (
    .clk_i          (sysclk),
    .rst_i          (rst),
    .req_i          (mem_req && device_sel[LED_ADDR_HIGH]),
    .write_enable_i (mem_we),
    .addr_i         (mem_addr),
    .write_data_i   (mem_wd),
    .read_data_o    (led_rd),
    .led_o          (led_o)
  );

  ps2_sb_ctrl ps2_ctrl (
    .clk_i               (sysclk),
    .rst_i               (rst),
    .addr_i              (mem_addr),
    .req_i               (mem_req && device_sel[PS2_ADDR_HIGH]),
    .write_data_i        (mem_wd),
    .write_enable_i      (mem_we),
    .read_data_o         (ps2_rd),
    .interrupt_request_o (ps2_irq),
    .interrupt_return_i  (irq_ret),
    .kclk_i              (kclk_i),
    .kdata_i             (kdata_i)
  );

  // Неиспользуемые выходы (vga_r_o, tx_o и т.д.) остаются неподключенными, 
  // как сказано в методичке. Vivado выдаст предупреждения, что они unused/floating, 
  // это нормально.

endmodule