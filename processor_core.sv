module processor_core (
  input  logic        clk_i,
  input  logic        rst_i,

  output logic [31:0] instr_addr_o,
  input  logic [31:0] instr_i,

  output logic [31:0] mem_addr_o,
  output logic [ 2:0] mem_size_o,
  output logic        mem_req_o,
  output logic        mem_we_o,
  output logic [31:0] mem_wd_o,
  input  logic [31:0] mem_rd_i,

  input  logic        stall_i,

  input  logic        irq_req_i,
  output logic        irq_ret_o
);

  import decoder_pkg::*;

  logic [31:0] pc;
  logic [31:0] pc_plus_4;
  logic [31:0] pc_next;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      pc <= 32'h0000_0000;
    end else if (!stall_i) begin
      pc <= pc_next;
    end
  end

  assign instr_addr_o = pc;

  fulladder32 pc_adder (
    .a_i     (pc),
    .b_i     (32'd4),
    .carry_i (1'b0),
    .sum_o   (pc_plus_4),
    .carry_o ()
  );

  logic [31:0] imm_i;
  logic [31:0] imm_s;
  logic [31:0] imm_b;
  logic [31:0] imm_u;
  logic [31:0] imm_j;
  logic [31:0] imm_z;

  assign imm_i = {{20{instr_i[31]}}, instr_i[31:20]};
  assign imm_s = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
  assign imm_b = {{19{instr_i[31]}}, instr_i[31], instr_i[7],
                  instr_i[30:25], instr_i[11:8], 1'b0};
  assign imm_u = {instr_i[31:12], 12'b0};
  assign imm_j = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12],
                  instr_i[20], instr_i[30:21], 1'b0};
  assign imm_z = {27'b0, instr_i[19:15]};

  logic [1:0] a_sel;
  logic [2:0] b_sel;
  logic [4:0] alu_op;
  logic [2:0] csr_op;
  logic       csr_we;
  logic       mem_req;
  logic       mem_we;
  logic [2:0] mem_size;
  logic       gpr_we;
  logic [1:0] wb_sel;
  logic       illegal_instr;
  logic       branch;
  logic       jal;
  logic       jalr;
  logic       mret;

  decoder decoder_inst (
    .fetched_instr_i (instr_i),
    .a_sel_o         (a_sel),
    .b_sel_o         (b_sel),
    .alu_op_o        (alu_op),
    .csr_op_o        (csr_op),
    .csr_we_o        (csr_we),
    .mem_req_o       (mem_req),
    .mem_we_o        (mem_we),
    .mem_size_o      (mem_size),
    .gpr_we_o        (gpr_we),
    .wb_sel_o        (wb_sel),
    .illegal_instr_o (illegal_instr),
    .branch_o        (branch),
    .jal_o           (jal),
    .jalr_o          (jalr),
    .mret_o          (mret)
  );

  logic [31:0] rf_rd1;
  logic [31:0] rf_rd2;
  logic [31:0] wb_data;

  register_file rf_inst (
    .clk_i          (clk_i),
    .write_enable_i (gpr_we),
    .write_addr_i   (instr_i[11:7]),
    .read_addr1_i   (instr_i[19:15]),
    .read_addr2_i   (instr_i[24:20]),
    .read_data1_o   (rf_rd1),
    .read_data2_o   (rf_rd2),
    .write_data_i   (wb_data)
  );

  logic        irq;
  logic [31:0] irq_cause;
  logic [31:0] mie;
  logic [31:0] csr_read_data;
  logic [31:0] mepc;
  logic [31:0] mtvec;
  logic        exception_req;

  assign exception_req = illegal_instr && (mtvec != 32'd0);

  interrupt_controller irq_ctrl (
    .clk_i       (clk_i),
    .rst_i       (rst_i),
    .exception_i (exception_req),
    .irq_req_i   (irq_req_i),
    .mie_i       (mie[16]),
    .mret_i      (mret),
    .irq_ret_o   (irq_ret_o),
    .irq_cause_o (irq_cause),
    .irq_o       (irq)
  );

  csr_controller csr_ctrl (
    .clk_i          (clk_i),
    .rst_i          (rst_i),
    .trap_i         (irq),
    .opcode_i       (csr_op),
    .addr_i         (instr_i[31:20]),
    .pc_i           (pc),
    .mcause_i       (irq_cause),
    .rs1_data_i     (rf_rd1),
    .imm_data_i     (imm_z),
    .write_enable_i (csr_we),
    .read_data_o    (csr_read_data),
    .mie_o          (mie),
    .mepc_o         (mepc),
    .mtvec_o        (mtvec)
  );

  logic [31:0] alu_a;
  logic [31:0] alu_b;

  always_comb begin
    case (a_sel)
      OP_A_RS1:     alu_a = rf_rd1;
      OP_A_CURR_PC: alu_a = pc;
      OP_A_ZERO:    alu_a = 32'd0;
      default:      alu_a = 32'd0;
    endcase
  end

  always_comb begin
    case (b_sel)
      OP_B_RS2:   alu_b = rf_rd2;
      OP_B_IMM_I: alu_b = imm_i;
      OP_B_IMM_U: alu_b = imm_u;
      OP_B_IMM_S: alu_b = imm_s;
      OP_B_INCR:  alu_b = 32'd4;
      default:    alu_b = 32'd0;
    endcase
  end

  logic        alu_flag;
  logic [31:0] alu_result;

  alu alu_inst (
    .a_i      (alu_a),
    .b_i      (alu_b),
    .alu_op_i (alu_op),
    .flag_o   (alu_flag),
    .result_o (alu_result)
  );

  always_comb begin
    case (wb_sel)
      WB_EX_RESULT: wb_data = alu_result;
      WB_LSU_DATA:  wb_data = mem_rd_i;
      WB_CSR_DATA:  wb_data = csr_read_data;
      default:      wb_data = alu_result;
    endcase
  end

  logic [31:0] jalr_sum;
  logic [31:0] jalr_target;

  fulladder32 jalr_adder (
    .a_i     (rf_rd1),
    .b_i     (imm_i),
    .carry_i (1'b0),
    .sum_o   (jalr_sum),
    .carry_o ()
  );

  assign jalr_target = {jalr_sum[31:1], 1'b0};

  always_comb begin
    if (irq) begin
      pc_next = mtvec;
    end else if (mret) begin
      pc_next = mepc;
    end else if (jal) begin
      pc_next = pc + imm_j;
    end else if (jalr) begin
      pc_next = jalr_target;
    end else if (branch && alu_flag) begin
      pc_next = pc + imm_b;
    end else begin
      pc_next = pc_plus_4;
    end
  end

  assign mem_addr_o = alu_result;
  assign mem_size_o = mem_size;
  assign mem_req_o  = mem_req;
  assign mem_we_o   = mem_we;
  assign mem_wd_o   = rf_rd2;

endmodule
