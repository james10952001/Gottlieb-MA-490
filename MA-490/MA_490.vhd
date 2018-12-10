-- VHDL implementation of the Gottlieb MA-490 sound board used in several System 80 pinball machines. 
-- Amazon Hunt, Rack'Em Up, Ready... Aim... Fire!, Jacks to Open, Touchdown, Alien Star, The Games, 
-- El Dorado City of Gold, Ice Fever.
--
-- S1 through S8 are sound control lines, all input signals are active-low.
-- Original hardware used a 6530 RRIOT, this is based on an adaptation to replace the RRIOT with a 
-- more commonly available 6532 RIOT and separate ROM. The MA-490 is based on the earlier MA-55 with 
-- an additional piggyback board containing additional ROM.
-- (c)2015 James Sweet
--
-- This is free software: you can redistribute
-- it and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- This is distributed in the hope that it will
-- be useful, but WITHOUT ANY WARRANTY; without even the
-- implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE. See the GNU General Public License
-- for more details.
--
-- Changelog:
-- V0.5 initial release
-- V1.0 
-- Removed 6530 mask ROM and associated logic, not used by MA-490 board anyway
-- Cleaned out unused signals

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity MA_490 is
	port(
		clk_358		:	in		std_logic; -- 3.58 MHz clock
		dac_clk		:	in		std_logic; -- DAC clock, 30-100 MHz works well
		Reset_l		:	in 	std_logic;	
		Test			:	in  	std_logic;
		Attract		:	in		std_logic:= '0'; -- 0 Enables attract mode, 1 disables
		S1				:  in		std_logic := '1';
		S2				: 	in 	std_logic := '1';
		S4				:	in 	std_logic := '1';
		S8				:	in 	std_logic := '1';
		Audio_O		: 	out	std_logic
		);
end MA_490;


architecture rtl of MA_490 is

signal clkCount		: std_logic_vector(1 downto 0);
signal cpu_clk		: std_logic;
signal phi2				: std_logic;

signal cpu_addr		: std_logic_vector(11 downto 0);
signal cpu_din		: std_logic_vector(7 downto 0);
signal cpu_dout		: std_logic_vector(7 downto 0);
signal riot_rs_n	: std_logic;
signal cpu_wr_n		: std_logic;
signal cpu_irq_n	: std_logic;

signal rom_dout		: std_logic_vector(7 downto 0);

signal riot_addr	: std_logic_vector(6 downto 0);
signal riot_dout	: std_logic_vector(7 downto 0);
signal riot_pb		: std_logic_vector(7 downto 0);
signal riot_pb_o	: std_logic_vector(7 downto 0);
signal riot_cs1  	: std_logic := '0';
signal irq_n			: std_logic;

signal u11_q			: std_logic;

signal audio			: std_logic_vector(7 downto 0);

begin
-- Divide 3.58 MHz from PLL down to 895 kHz CPU clock, real hardware uses R-C oscillator but starting with 
-- 3.58 MHz is consistent with other sound board designs, makes it easier to interface
Clock_div: process(clk_358) 
begin
	if rising_edge(clk_358) then
		ClkCount <= ClkCount + 1;
		cpu_clk <= ClkCount(1);
	end if;
end process;

U1: entity work.T65 -- Real circuit used 6503, same as 6502 but fewer pins
port map(
	Mode    			=> "00",
	Res_n   			=> reset_l,
	Enable  			=> '1',
	Clk     			=> cpu_clk,
	Rdy     			=> '1',
	Abort_n 			=> '1',
	IRQ_n   			=> cpu_irq_n,
	NMI_n   			=> test,
	SO_n    			=> '1',
	R_W_n 			=> cpu_wr_n,
	A(11 downto 0)	=> cpu_addr,       
	DI     			=> cpu_din,
	DO    			=> cpu_dout
	);
	
U2: entity work.RIOT -- Should be 6530 RRIOT but using a RIOT instead, with a separate ROM
port map(
	PHI2   => phi2,
   RES_N  => reset_l,
   CS1    => riot_cs1,
   CS2_N  => '0',
   RS_N   => riot_rs_n,
   R_W    => cpu_wr_n,
   A      => riot_addr,
   D_I	 => cpu_dout,
	D_O	 => riot_dout,
	PA_I	 => x"00",
   PA_O   => audio,
	DDRA_O => open,
   PB_I   => riot_pb,
	PB_O	 => riot_pb_o,
	DDRB_O => open,
	IRQ_N  => open 
   );

U9: entity work.SND_ROM -- ROM containing the game-specific sound code
port map(
	address => cpu_addr(10 downto 0),
	clock => clk_358,
	q => rom_dout
	);

U3: entity work.DAC
  generic map(
  msbi_g => 7)
port  map(
   clk_i   => dac_clk,
   res_n_i => reset_l,
   dac_i   => audio,
   dac_o   => audio_O
);

-- Phase 2 clock is complement of CPU clock
phi2 <= not cpu_clk; 

-- Option switches
riot_pb(4) <= attract; -- Attract mode sounds enable
riot_pb(7) <= '1'; --sound_tones; -- Sound or tones mode, most games lack tone support and require this to be high 

-- Sound selection inputs
riot_pb(0) <= (not S1);
riot_pb(1) <= (not S2);
riot_pb(2) <= (not S4);
riot_pb(3) <= (not S8);

-- Address decoding
cpu_din <=
	riot_dout when riot_cs1 = '1' else
	rom_dout when cpu_addr(11) = '1' else
	x"FF";
	
-- Signal assignments		
irq_n <= riot_pb_o(6);	
riot_cs1 <= (not cpu_addr(11));
riot_rs_n <= cpu_addr(9);
riot_pb(5) <= '0';

-- RIOT address lines adapted to match RRIOT configuration
riot_addr(3 downto 0) <= cpu_addr(3 downto 0);
riot_addr(4) <= '1';
riot_addr(6 downto 5) <= cpu_addr(5 downto 4);	

-- U11 on piggyback board generates IRQ from sound select inputs	
U11_q <= not (riot_pb(0) or riot_pb(1) or riot_pb(2) or riot_pb(3));

-- JK flip-flop on the piggyback board triggers CPU IRQ
U10: process(U11_q, IRQ_N)
begin
	if IRQ_N = '0' then
		cpu_irq_n <= '1';
	elsif falling_edge(U11_q) then 
		cpu_irq_n <= '0';
	end if;
end process;

end rtl;
		