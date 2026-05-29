module interrupt_controller (
  input  logic        clk_i,
  input  logic        rst_i,
  input  logic        exception_i,
  input  logic        irq_req_i,
  input  logic        mie_i,
  input  logic        mret_i,

  output logic        irq_ret_o,
  output logic [31:0] irq_cause_o,
  output logic        irq_o
);

  logic exc_h;
  logic irq_h;
  logic take_exception;
  logic take_irq;

  assign take_exception = exception_i && !exc_h;
  assign take_irq       = irq_req_i && mie_i && !exception_i && !exc_h && !irq_h;

  assign irq_o       = take_exception || take_irq;
  assign irq_cause_o = take_exception ? 32'h0000_0002 : 32'h8000_0010;
  assign irq_ret_o   = mret_i && !exc_h && irq_h;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      exc_h <= 1'b0;
    end else if (mret_i) begin
      exc_h <= 1'b0;
    end else if (take_exception) begin
      exc_h <= 1'b1;
    end
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      irq_h <= 1'b0;
    end else if (irq_ret_o) begin
      irq_h <= 1'b0;
    end else if (take_irq) begin
      irq_h <= 1'b1;
    end
  end

endmodule
