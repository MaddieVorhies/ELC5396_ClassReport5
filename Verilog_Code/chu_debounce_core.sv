module chu_debounce_core
   #(parameter W = 8,  // width of input port // how many debounce wires you have coming in
               N = 20  // # bit for 10-ms tick 2^N * clk period //Fastest rate to sample at // Only have to change it if you want to count slower
   )
   (
    input  logic clk,
    input  logic reset,
    // slot interface
    input  logic cs,
    input  logic read,
    input  logic write,
    input  logic [4:0] addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    // external signal    
    input logic [W-1:0] din
   );

   // signal declaration
   logic [W-1:0] rd_data_reg;
   logic ms10_tick;
   logic [W-1:0] db_out;
   
   // body
   // input register
   always_ff @(posedge clk, posedge reset)
      if (reset)
         rd_data_reg <= 0;
      else   
      	 rd_data_reg <= din;

   // instantiate 10-ms counter
   debounce_counter  #(.N(N)) db_counter_unit (.*); //.* means use all the same names
   // instantiate FSMs
   generate
      genvar i;
      for (i=0; i<W; i=i+1) 
      begin:  fsm_cell_gen //begin: means that it is naming something - this begin unit is called fsm_cell_gen
         debounce_fsm  db_fsm_unit (.*, .btn(din[i]), .db(db_out[i])); // This is what is being built  //din - raw data coming in
      end                                                              // db_out - debounced data coming out
   endgenerate

   // read multiplexing   
   assign rd_data[W-1:0] = (addr[0]) ? db_out : rd_data_reg; //rd_data_reg - is the raw data (register 0 is raw data, register 1 is the debounce data)
   assign rd_data[31:W] = 0;
endmodule  


