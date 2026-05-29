module decoder (
  input  logic [31:0]  fetched_instr_i,
  output logic [1:0]   a_sel_o,
  output logic [2:0]   b_sel_o,
  output logic [4:0]   alu_op_o,
  output logic [2:0]   csr_op_o,
  output logic         csr_we_o,
  output logic         mem_req_o,
  output logic         mem_we_o,
  output logic [2:0]   mem_size_o,
  output logic         gpr_we_o,
  output logic [1:0]   wb_sel_o,
  output logic         illegal_instr_o,
  output logic         branch_o,
  output logic         jal_o,
  output logic         jalr_o,
  output logic         mret_o
);
  import decoder_pkg::*;
  import alu_opcodes_pkg::*;

  logic [4:0] opcode;
  logic [2:0] func3;
  logic [6:0] func7;

  assign opcode = fetched_instr_i[6:2];
  assign func3  = fetched_instr_i[14:12];
  assign func7  = fetched_instr_i[31:25];

  always_comb begin
    illegal_instr_o = 1'b0;
    gpr_we_o        = 1'b0;
    mem_req_o       = 1'b0;
    mem_we_o        = 1'b0;
    csr_we_o        = 1'b0;
    branch_o        = 1'b0;
    jal_o           = 1'b0;
    jalr_o          = 1'b0;
    mret_o          = 1'b0;

    a_sel_o         = OP_A_RS1;
    b_sel_o         = OP_B_RS2;
    alu_op_o        = ALU_ADD;
    wb_sel_o        = WB_EX_RESULT;
    mem_size_o      = func3;
    csr_op_o        = func3;

    if (fetched_instr_i[1:0] != 2'b11) begin
      illegal_instr_o = 1'b1;
    end else begin
      case (opcode)
        LUI_OPCODE: begin
          a_sel_o  = OP_A_ZERO;
          b_sel_o  = OP_B_IMM_U;
          gpr_we_o = 1'b1;
        end

        AUIPC_OPCODE: begin
          a_sel_o  = OP_A_CURR_PC;
          b_sel_o  = OP_B_IMM_U;
          gpr_we_o = 1'b1;
        end

        JAL_OPCODE: begin
          a_sel_o  = OP_A_CURR_PC;
          b_sel_o  = OP_B_INCR;
          jal_o    = 1'b1;
          gpr_we_o = 1'b1;
        end

        JALR_OPCODE: begin
          if (func3 == 3'b000) begin
            a_sel_o  = OP_A_CURR_PC;
            b_sel_o  = OP_B_INCR;
            jalr_o   = 1'b1;
            gpr_we_o = 1'b1;
          end else illegal_instr_o = 1'b1;
        end

        BRANCH_OPCODE: begin
          branch_o = 1'b1;
          case (func3)
            3'b000:  alu_op_o = ALU_EQ;
            3'b001:  alu_op_o = ALU_NE;
            3'b100:  alu_op_o = ALU_LTS;
            3'b101:  alu_op_o = ALU_GES;
            3'b110:  alu_op_o = ALU_LTU;
            3'b111:  alu_op_o = ALU_GEU;
            default: illegal_instr_o = 1'b1;
          endcase
        end

        LOAD_OPCODE: begin
          if (func3 == 3'b011 || func3 > 3'b101) begin
            illegal_instr_o = 1'b1;
          end else begin
            b_sel_o   = OP_B_IMM_I;
            mem_req_o = 1'b1;
            gpr_we_o  = 1'b1;
            wb_sel_o  = WB_LSU_DATA;
          end
        end

        STORE_OPCODE: begin
          if (func3 > 3'b010) begin
            illegal_instr_o = 1'b1;
          end else begin
            b_sel_o   = OP_B_IMM_S;
            mem_req_o = 1'b1;
            mem_we_o  = 1'b1;
          end
        end

        OP_IMM_OPCODE: begin
          b_sel_o  = OP_B_IMM_I;
          gpr_we_o = 1'b1;
          case (func3)
            3'b000: alu_op_o = ALU_ADD;
            3'b010: alu_op_o = ALU_SLTS;
            3'b011: alu_op_o = ALU_SLTU;
            3'b100: alu_op_o = ALU_XOR;
            3'b110: alu_op_o = ALU_OR;
            3'b111: alu_op_o = ALU_AND;
            3'b001: begin
              alu_op_o = ALU_SLL;
              if (func7 != 7'b0000000) illegal_instr_o = 1'b1;
            end
            3'b101: begin
              if (func7 == 7'b0000000)      alu_op_o = ALU_SRL;
              else if (func7 == 7'b0100000) alu_op_o = ALU_SRA;
              else                          illegal_instr_o = 1'b1;
            end
            default: illegal_instr_o = 1'b1;
          endcase
        end

        OP_OPCODE: begin
          gpr_we_o = 1'b1;
          case ({func7, func3})
            {7'b0000000, 3'b000}: alu_op_o = ALU_ADD;
            {7'b0100000, 3'b000}: alu_op_o = ALU_SUB;
            {7'b0000000, 3'b001}: alu_op_o = ALU_SLL;
            {7'b0000000, 3'b010}: alu_op_o = ALU_SLTS;
            {7'b0000000, 3'b011}: alu_op_o = ALU_SLTU;
            {7'b0000000, 3'b100}: alu_op_o = ALU_XOR;
            {7'b0000000, 3'b101}: alu_op_o = ALU_SRL;
            {7'b0100000, 3'b101}: alu_op_o = ALU_SRA;
            {7'b0000000, 3'b110}: alu_op_o = ALU_OR;
            {7'b0000000, 3'b111}: alu_op_o = ALU_AND;
            default: illegal_instr_o = 1'b1;
          endcase
        end

        SYSTEM_OPCODE: begin
          if (func3 == 3'b000) begin
            // MRET (32'h30200073)
            if (fetched_instr_i == 32'h30200073) begin
              mret_o = 1'b1;
            end else begin
              // ECALL/EBREAK по заданию -> illegal
              illegal_instr_o = 1'b1;
            end
          end else begin
            // CSR операции
            if (func3 == 3'b100) begin
              illegal_instr_o = 1'b1;
            end else begin
              gpr_we_o = 1'b1;
              csr_we_o = 1'b1;
              wb_sel_o = WB_CSR_DATA;
            end
          end
        end

        MISC_MEM_OPCODE: begin
          if (func3 != 3'b000) illegal_instr_o = 1'b1;
        end

        default: illegal_instr_o = 1'b1;
      endcase
    end

    if (illegal_instr_o) begin
      gpr_we_o  = 1'b0;
      mem_req_o = 1'b0;
      mem_we_o  = 1'b0;
      csr_we_o  = 1'b0;
      branch_o  = 1'b0;
      jal_o     = 1'b0;
      jalr_o    = 1'b0;
      mret_o    = 1'b0;
    end
  end

endmodule
