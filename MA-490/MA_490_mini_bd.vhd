-- Top level file for testing the System 80 sound board. This provides the needed clock signals and a PS/2 keyboard
-- interface for testing purposes. This should be replaced with a top level file tailored to the FPGA board you are using.
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity MA_490_mini_bd is
	port(
		clk_50	: in std_logic;
		Reset_l	: in std_logic;
		ps2_clk	: inout std_logic;
		ps2_dat	: inout std_logic;
		Test		: in std_logic;
		Audio_O	: out std_logic
		);
end MA_490_mini_bd;

architecture rtl of MA_490_mini_bd is 

signal clk		 : std_logic;
signal clk_358	 : std_logic;
signal snd_crtl : std_logic_vector(3 downto 0);
signal clkcount : std_logic_vector(1 downto 0);
signal reset_h	 : std_logic;

-- PS/2 interface signals
signal codeReady	: std_logic;
signal scanCode	: std_logic_vector(9 downto 0);
signal send 		: std_logic;
signal Command 	: std_logic_vector(7 downto 0);
signal PS2Busy		: std_logic;
signal PS2Error	: std_logic;
signal dataByte	: std_logic_vector(7 downto 0);
signal dataReady	: std_logic;

begin
Core: entity work.MA_490
port map(
	clk_358 => clk_358,
	dac_clk => clk_50,
	reset_l => reset_l,
	S1 => snd_crtl(0),
	S2 => snd_crtl(1),
	S4 => snd_crtl(2),
	S8 => snd_crtl(3),
	Test => Test,
	Attract => '1',
	Audio_o => audio_o
	);

Clock_gen: entity work.CLK_PLL -- PLL takes the 50 MHz input clock and generates 14.3 MHz
port map(
   areset => reset_h,
	inclk0 => clk_50,
	c0	=> clk
);

Clock_div: process(clk) -- Divide 14.3 MHz from PLL down to 3.58 MHz clock used by CPU board
begin
	if rising_edge(clk) then
		ClkCount <= ClkCount + 1;
		clk_358 <= ClkCount(1);
	end if;
end process;

reset_h <= (not reset_l); -- Active high reset from active low reset

-- PS/2 keyboard controller
keyboard: entity work.PS2Controller
port map(
		Reset     => reset_h,
		Clock     => clk_50,
		PS2Clock  => ps2_clk,
		PS2Data   => ps2_dat,
		Send      => send,
		Command   => command,
		PS2Busy   => ps2Busy,
		PS2Error  => ps2Error,
		DataReady => dataReady,
		DataByte  => dataByte
		);

-- PS/2 scancode decoder	
decoder: entity work.KeyboardMapper
port map(
		Clock     => clk_50,
		Reset     => reset_h,
		PS2Busy   => ps2Busy,
		PS2Error  => ps2Error,
		DataReady => dataReady,
		DataByte  => dataByte,
		Send      => send,
		Command   => command,
		CodeReady => codeReady,
		ScanCode  => scanCode
		);

-- Connect PS2 scancodes to sound control inputs, 15 possible inputs decoded to specific keys
-- Q W E R T Y U I O P A S D F G
scan_decode : process(scancode)
   begin
		if scancode(8) = '0' then
			case scancode(7 downto 0) is
			when x"15" =>
				snd_crtl <= "0001";
			when x"1D" =>
				snd_crtl <= "0010";
			when x"24" =>
				snd_crtl <= "0011";
			when x"2D" =>
				snd_crtl <= "0100";
			when x"2C" =>
				snd_crtl <= "0101";
			when x"35" =>
				snd_crtl <= "0110";
			when x"3C" =>
				snd_crtl <= "0111";
			when x"43" =>
				snd_crtl <= "1000";
			when x"44" =>
				snd_crtl <= "1001";
			when x"4D" =>
				snd_crtl <= "1010";
			when x"1C" =>
				snd_crtl <= "1011";
			when x"1B" =>
				snd_crtl <= "1100";
			when x"23" => 
				snd_crtl <= "1101";
			when x"2B" =>
				snd_crtl <= "1110";
			when x"34" =>
				snd_crtl <= "0000";
			when others =>
				snd_crtl <= "1111";
			end case;
		else snd_crtl <= "1111";
		end if;
   end process;
end rtl;