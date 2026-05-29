module fulladder32(
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic        carry_i,
    output logic [31:0] sum_o,
    output logic        carry_o
);

logic[31:0] carry_i_vector;
logic[31:0] carry_o_vector;

assign carry_i_vector[0] = carry_i;
assign carry_i_vector[31:1] = carry_o_vector[30:0];
assign carry_o = carry_o_vector[31];

fulladder fulladder32_module[31:0] (
    .a_i(a_i),
    .b_i(b_i),
    .carry_i(carry_i_vector),
    .sum_o(sum_o),
    .carry_o(carry_o_vector)
);

endmodule
