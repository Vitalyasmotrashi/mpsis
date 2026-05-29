module instr_mem
import memory_pkg::INSTR_MEM_SIZE_BYTES;
import memory_pkg::INSTR_MEM_SIZE_WORDS;
(
  input  logic [31:0] read_addr_i,
  output logic [31:0] read_data_o
);

  logic [31:0] ROM [INSTR_MEM_SIZE_WORDS];  // создать пам€ть с
                                            // <INSTR_MEM_SIZE_WORDS>
                                            // 32-битных €чеек

  initial begin
    $readmemh("program.mem", ROM);          // поместить в пам€ть ROM содержимое
  end                                       // файла program.mem

  // –еализаци€ асинхронного порта на чтение, где на выход идЄт €чейка пам€ти
  // инструкций, расположенна€ по адресу read_addr_i, в котором отброшены два
  // младших бита, а также биты, двоичный вес которых превышает размер пам€ти
  // данных в байтах.
  // ƒва младших бита отброшены, чтобы обеспечить выровненный доступ к пам€ти,
  // в то врем€ как старшие биты отброшены, чтобы не дать обращатьс€ в пам€ть
  // по адресам несуществующих €чеек (вместо этого будут выданы данные €чеек,
  // расположенных по младшим адресам).
  assign read_data_o = ROM[read_addr_i[$clog2(INSTR_MEM_SIZE_BYTES)-1:2]];

endmodule