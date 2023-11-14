`include "chu_io_map.svh"
module mmio_sys_vanilla 
#(
   parameter N_SW = 8,
   parameter N_LED = 8
)	
(
   input logic clk,
   input  logic reset,
   // FPro bus 
   input  logic mmio_cs,
   input  logic mmio_wr,
   input  logic mmio_rd,
   input  logic [20:0] mmio_addr, // 11 LSB used; 2^6 slots; 2^5 reg each 
   input  logic [31:0] mmio_wr_data,
   output logic [31:0] mmio_rd_data,
   // switches and LEDs
   input logic [N_SW-1:0] sw,
   output logic [N_LED-1:0] led,
   // uart
   input logic rx,
   output logic tx, 
   //XADC     
   input logic [3:0] adc_p, // 4 analog signals to read from
   input logic [3:0] adc_n,
   //sseg
   output logic [7:0] sseg, an,
   //spi
   output logic acl_sclk, acl_mosi,
   input  logic acl_miso,
   output logic acl_ss_n,
   // i2c temperature sensor  
   output logic tmp_i2c_scl,
   inout  tri tmp_i2c_sda
);

   // declaration
   logic [63:0] mem_rd_array; // dedicated message, makes sure it goes to the right signal
   logic [63:0] mem_wr_array; // dedicated message, makes sure it goes to the right signal
   logic [63:0] cs_array; // dedicated message, makes sure it goes to the right signal  //cs - chip select, tells it when its there turn
   logic [4:0] reg_addr_array [63:0]; //Shared by everyone // 5-bits, which means it will hold 32 different values (2^5 = 32)
   logic [31:0] rd_data_array [63:0]; //Shared by everyone // left side is the data type - 32 bits of logic and you want 64 of them
   logic [31:0] wr_data_array [63:0]; //Shared by everyone // vector[64] of 32-bit logic variables

   // body
   // instantiate mmio controller 
   chu_mmio_controller ctrl_unit
   (.clk(clk),
    .reset(reset),
    .mmio_cs(mmio_cs),
    .mmio_wr(mmio_wr),
    .mmio_rd(mmio_rd),
    .mmio_addr(mmio_addr), 
    .mmio_wr_data(mmio_wr_data),
    .mmio_rd_data(mmio_rd_data),
    // slot interface
    .slot_cs_array(cs_array),
    .slot_mem_rd_array(mem_rd_array),
    .slot_mem_wr_array(mem_wr_array),
    .slot_reg_addr_array(reg_addr_array),
    .slot_rd_data_array(rd_data_array), 
    .slot_wr_data_array(wr_data_array)
    );
  
   // slot 0: system timer 
   chu_timer timer_slot0  //Wrapper - standard bus setup
   (.clk(clk),
    .reset(reset),
    .cs(cs_array[`S0_SYS_TIMER]),
    .read(mem_rd_array[`S0_SYS_TIMER]),
    .write(mem_wr_array[`S0_SYS_TIMER]), // the array is picking the dedicated line for thew S0 system timer
    .addr(reg_addr_array[`S0_SYS_TIMER]), // leading quote is used to pull the value to replace S0_SYS_TIMER with
    .rd_data(rd_data_array[`S0_SYS_TIMER]),
    .wr_data(wr_data_array[`S0_SYS_TIMER])
    );

   // slot 1: UART 
   chu_uart uart_slot1  // you'll copy and paste this and change the pink then add the signals you need
   (.clk(clk),
    .reset(reset),
    .cs(cs_array[`S1_UART1]),
    .read(mem_rd_array[`S1_UART1]),
    .write(mem_wr_array[`S1_UART1]),
    .addr(reg_addr_array[`S1_UART1]),
    .rd_data(rd_data_array[`S1_UART1]),
    .wr_data(wr_data_array[`S1_UART1]), 
    .tx(tx),  // Only pass these if your using them - these should only go to one slot module
    .rx(rx)   // Only pass these if your using them
    );
   //assign rd_data_array[1] = 32'h00000000;

   // slot 2: gpo 
   chu_gpo #(.W(N_LED)) gpo_slot2 
   (.clk(clk),
    .reset(reset),
    .cs(cs_array[`S2_LED]),
    .read(mem_rd_array[`S2_LED]),
    .write(mem_wr_array[`S2_LED]),
    .addr(reg_addr_array[`S2_LED]),
    .rd_data(rd_data_array[`S2_LED]),
    .wr_data(wr_data_array[`S2_LED]),
    .dout(led)
    );

   // slot 3: gpi 
   chu_gpi #(.W(N_SW)) gpi_slot3 
   (.clk(clk),
    .reset(reset),
    .cs(cs_array[`S3_SW]),
    .read(mem_rd_array[`S3_SW]),
    .write(mem_wr_array[`S3_SW]),
    .addr(reg_addr_array[`S3_SW]),
    .rd_data(rd_data_array[`S3_SW]),
    .wr_data(wr_data_array[`S3_SW]),
    .din(sw)
    );
    // slot 4: User (add it in)
    // slot 5: xadc
   chu_xadc_core xadc_slot5 
   (.clk(clk),
    .reset(reset),
    .cs(cs_array[`S5_XADC]),
    .read(mem_rd_array[`S5_XADC]),
    .write(mem_wr_array[`S5_XADC]),
    .addr(reg_addr_array[`S5_XADC]),
    .rd_data(rd_data_array[`S5_XADC]),
    .wr_data(wr_data_array[`S5_XADC]),
    .adc_p(adc_p),
    .adc_n(adc_n)
    );
    
    // slot 8: sseg
   chu_led_mux_core sseg_slot8 
   (.clk(clk),
    .reset(reset),
    .cs(cs_array[`S8_SSEG]),
    .read(mem_rd_array[`S8_SSEG]),
    .write(mem_wr_array[`S8_SSEG]),
    .addr(reg_addr_array[`S8_SSEG]),
    .rd_data(rd_data_array[`S8_SSEG]),
    .wr_data(wr_data_array[`S8_SSEG]),
    .sseg(sseg),
    .an(an)
    );
    
    // slot 9: spi 
   chu_spi_core #(.S(1)) spi_slot9 
   (.clk(clk),
    .reset(reset),
    .cs(cs_array[`S9_SPI]),
    .read(mem_rd_array[`S9_SPI]),
    .write(mem_wr_array[`S9_SPI]),
    .addr(reg_addr_array[`S9_SPI]),
    .rd_data(rd_data_array[`S9_SPI]),
    .wr_data(wr_data_array[`S9_SPI]),
    .spi_sclk(acl_sclk),
    .spi_mosi(acl_mosi),
    .spi_miso(acl_miso),
    .spi_ss_n(acl_ss_n)
    );
    
    // slot 10: i2c 
    chu_i2c_core i2c_slot10 
    (.clk(clk),
     .reset(reset),
     .cs(cs_array[`S10_I2C]),
     .read(mem_rd_array[`S10_I2C]),
     .write(mem_wr_array[`S10_I2C]),
     .addr(reg_addr_array[`S10_I2C]),
     .rd_data(rd_data_array[`S10_I2C]),
     .wr_data(wr_data_array[`S10_I2C]),
     .scl(tmp_i2c_scl),
     .sda(tmp_i2c_sda)
     );
    
   // assign 0's to all unused slot rd_data signals
   // This needs to be modified
   // He built everything up through 3, so essentially he is putting a plug on everything from 4 and then on
   generate
      genvar i;
      for (i=11; i<64; i=i+1) begin:  unused_slot_gen
         assign rd_data_array[i] = 32'hffffffff;
      end
   endgenerate
endmodule


   // slot interface
   //output wire [63:0] slot_cs_array,
   //output wire [63:0] slot_mem_rd_array,
   //output wire [63:0] slot_mem_wr_array,
   //output wire [4:0]  slot_reg_addr_array [0:63],
   //input wire  [31:0] slot_rd_data_array [63:0], 
   //output wire [31:0] slot_wr_data_array [63:0]
   // verilog not allow 2d-array port
   //output wire [64*4-1:0]  slot_reg_addr_1d,
   //input wire  [64*32-1:0] slot_rd_data_1d, 
   //output wire [64*32-1:0] slot_wr_data_1d
   
//entity mmio_sys_vanilla is
//   generic(
//     N_LED: integer;
//     N_SW: integer
//	);  
//   port(
//      -- FPro bus
//      clk          : in  std_logic;
//      reset        : in  std_logic;
//      mmio_cs      : in  std_logic;
//      mmio_wr      : in  std_logic;
//      mmio_rd      : in  std_logic;
//      mmio_addr    : in  std_logic_vector(20 downto 0); -- only 11 LSBs used
//      mmio_wr_data : in  std_logic_vector(31 downto 0);
//      mmio_rd_data : out std_logic_vector(31 downto 0);
//      -- switches and LEDs
//      sw           : in  std_logic_vector(N_SW-1 downto 0);
//      led          : out std_logic_vector(N_LED-1 downto 0);
//      -- uart
//      rx           : in  std_logic;
//      tx           : out std_logic
//   );
//end mmio_sys_vanilla;
//
//architecture arch of mmio_sys_vanilla is
//   signal cs_array       : std_logic_vector(63 downto 0);
//   signal reg_addr_array : slot_2d_reg_type;
//   signal mem_rd_array   : std_logic_vector(63 downto 0);
//   signal mem_wr_array   : std_logic_vector(63 downto 0);
//   signal rd_data_array  : slot_2d_data_type;
//   signal wr_data_array  : slot_2d_data_type;
//
//begin
//   --******************************************************************
//   --  MMIO controller instantiation  
//   --******************************************************************
//   ctrl_unit : entity work.chu_mmio_controller
//      port map(
//         -- FPro bus interface
//         mmio_cs             => mmio_cs,
//         mmio_wr             => mmio_wr,
//         mmio_rd             => mmio_rd,
//         mmio_addr           => mmio_addr,
//         mmio_wr_data        => mmio_wr_data,
//         mmio_rd_data        => mmio_rd_data,
//         -- 64 slot interface
//         slot_cs_array       => cs_array,
//         slot_reg_addr_array => reg_addr_array,
//         slot_mem_rd_array   => mem_rd_array,
//         slot_mem_wr_array   => mem_wr_array,
//         slot_rd_data_array  => rd_data_array,
//         slot_wr_data_array  => wr_data_array
//      );
//
//   --******************************************************************
//   -- IO slots instantiations
//   --******************************************************************
//   -- slot 0: system timer 
//   timer_slot0 : entity work.chu_timer
//      port map(
//         clk           => clk,
//         reset         => reset,
//         cs            => cs_array[S0_SYS_TIMER],
//         read          => mem_rd_array[S0_SYS_TIMER],
//         write         => mem_wr_array[S0_SYS_TIMER],
//         addr          => reg_addr_array[S0_SYS_TIMER],
//         rd_data       => rd_data_array[S0_SYS_TIMER],
//         wr_data       => wr_data_array[S0_SYS_TIMER]
//      );
//
//   -- slot 1: uart1     
//   uart1_slot1 : entity work.chu_uart
//      generic map(FIFO_DEPTH_BIT => 6)
//      port map(
//         clk     => clk,
//         reset   => reset,
//         cs      => cs_array[S1_UART],
//         read    => mem_rd_array[S1_UART],
//         write   => mem_wr_array[S1_UART],
//         addr    => reg_addr_array[S1_UART],
//         rd_data => rd_data_array[S1_UART],
//         wr_data => wr_data_array[S1_UART],
//         -- external signals
//         tx      => tx,
//         rx      => rx
//      );
//
//   -- slot 2: GPO for LEDs
//   gpo_slot2 : entity work.chu_gpo
//      generic map(W => N_LED)
//      port map(
//         clk     => clk,
//         reset   => reset,
//         cs      => cs_array[S2_LED],
//         read    => mem_rd_array[S2_LED],
//         write   => mem_wr_array[S2_LED],
//         addr    => reg_addr_array[S2_LED],
//         rd_data => rd_data_array[S2_LED],
//         wr_data => wr_data_array[S2_LED],
//         -- external signal
//         dout    => led
//      );
//
//   -- slot 3: input port for switches     
//   gpi_slot3 : entity work.chu_gpi
//      generic map(W => N_SW)
//      port map(
//         clk     => clk,
//         reset   => reset,
//         cs      => cs_array[S3_SW],
//         read    => mem_rd_array[S3_SW],
//         write   => mem_wr_array[S3_SW],
//         addr    => reg_addr_array[S3_SW],
//         rd_data => rd_data_array[S3_SW],
//         wr_data => wr_data_array[S3_SW],
//         -- external signal
//         din     => sw
//      );
//
//   -- assign 0's to all unused slot rd_data signals 
//   gen_unused_slot : for i in 4 to 63 generate
//      rd_data_array(i) <= (others => '0');
//   end generate gen_unused_slot;
//end arch;
