-------------------------------------------------------------------------------
-- Title      : A block which sends data to HIBI ver B.
-- Project    : 
-------------------------------------------------------------------------------
-- File       : basic_test_tx.vhd
-- Author     : ege
-- Created    : 2010-03-24
-- Last update: 2010-10-08
--
--
-------------------------------------------------------------------------------
-- Copyright (c) 2010
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


use std.textio.all;
use ieee.std_logic_textio.all;                     -- 2010-10-06 for hread

use work.basic_test_pkg.all;            -- read_conf_file()

entity basic_test_tx is

  generic (
    conf_file_g  : string  := "";
    comm_width_g : integer := 3;
    data_width_g : integer := 0
    );
  port (
    clk   : in std_logic;
    rst_n : in std_logic;

    done_out : out std_logic;           -- if this has finished

    -- HIBI wrapper ports
    agent_av_out   : out std_logic;
    agent_data_out : out std_logic_vector(data_width_g-1 downto 0);
    agent_comm_out : out std_logic_vector (comm_width_g-1 downto 0);
    agent_we_out   : out std_logic;
    agent_full_in  : in  std_logic;
    agent_one_p_in : in  std_logic
    );

end basic_test_tx;


architecture rtl of basic_test_tx is


  
  type control_states is (read_conf, wait_sending, wr_addr, wr_data, finish);
  signal curr_state_r : control_states := read_conf;

  signal delay_r    : integer;




  -- Registers may be reset to 'Z' to 'X' so that reset state is clearly
  -- distinguished from active state. Using dbg_level+Rst_Value array, the rst value may
  -- be easily set to '0' for synthesis.
  constant dbg_level : integer range 0 to 3 := 0;  -- 0= no debug
  constant rst_value_arr : std_logic_vector (6 downto 0) := 'X' & 'Z' & 'X' & 'Z' & 'X' & 'Z' & '0';
  -- Right now gives a lot of warnings when other than 0

  
begin  -- rtl

  main : process (clk, rst_n)
    file conf_data_file : text open read_mode is conf_file_g;

    variable delay_v    : integer;
    variable dst_ag_v   : integer;
    variable data_val_v : integer;
    variable cmd_v      : integer;

  begin  -- process main
    if rst_n = '0' then                 -- asynchronous reset (active low)
      curr_state_r   <= read_conf;
      agent_av_out   <= '0';
      agent_data_out <= (others => rst_value_arr(dbg_level*1));
      agent_comm_out <= (others => rst_value_arr(dbg_level*1));
      agent_we_out   <= '0';
      done_out       <= '0';

      delay_v    := 0;
      dst_ag_v   := 0;
      data_val_v := 0;
      cmd_v      := 0;

    elsif clk'event and clk = '1' then  -- rising clock edge

      case curr_state_r is
        when read_conf =>
          if agent_full_in = '0' then
            -- Read next transfer from file if FIFO has space
            -- and the whole file has not yet been read
            if endfile(conf_data_file) then
              curr_state_r <= finish;
              assert false report "End of the configuration file reached" severity note;
            else
              read_conf_file (
                delay        => delay_v,
                dest_agent_n => dst_ag_v,
                value        => data_val_v,
                cmd          => cmd_v,
                conf_dat     => conf_data_file);

              -- FSM causes few empty cycles, compensate by decrementing delay_v
              delay_v := delay_v -1;

              if cmd_v = -1 then
                cmd_v := 2; --use write as default
              end if;
              
              if delay_v < 1 then
                if dst_ag_v = 0 then
                  curr_state_r <= wr_data;
                else
                  curr_state_r <= wr_addr;
                end if;
              else
                curr_state_r <= wait_sending;
              end if;  -- delay_v              
              
            end if;  -- endfile
            agent_av_out   <= '0';
            agent_data_out <= (others => rst_value_arr(dbg_level*1));
            agent_comm_out <= (others => rst_value_arr(dbg_level*1));
            agent_we_out   <= '0';

            delay_r <= delay_v;

          else
            -- Keep the old values
            -- i.e. either the reset values or keep sending
            curr_state_r <= read_conf;
          end if;
          

        when wait_sending =>
          -- Wait for a given num of cycles before sending
--          delay_v    := delay_v-1;
--          if delay_r = 0 then
          delay_r    <= delay_r-1;
          if delay_r < 2 then
            if dst_ag_v = 0 then
              -- Skip the address and send data directly
              curr_state_r <= wr_data;
            else
              curr_state_r <= wr_addr;
            end if;
          else
            curr_state_r <= wait_sending;
          end if;

          
        when wr_addr =>
          if agent_full_in = '0' then
            -- Write the address  if there is room in HIBI's tx FIFO
            agent_av_out   <= '1';
            agent_data_out <= std_logic_vector (to_signed(dst_ag_v, data_width_g));
            agent_comm_out <= std_logic_vector (to_signed(cmd_v, comm_width_g));
            agent_we_out   <= '1';
            curr_state_r   <= wr_data;
          else
            -- Don't start yet, wait that there is space in FIFO
            agent_av_out   <= '0';
            agent_data_out <= (others => rst_value_arr(dbg_level*1));
            agent_comm_out <= (others => rst_value_arr(dbg_level*1));
            agent_we_out   <= '0';
            curr_state_r   <= wr_addr;
          end if;



        when wr_data =>
          if agent_full_in = '0' then
            -- Write the requested data value if there is room in HIBI's tx FIFO
            agent_av_out   <= '0';
            agent_data_out <= std_logic_vector (to_signed(data_val_v, data_width_g));
            agent_comm_out <= std_logic_vector (to_signed(cmd_v, comm_width_g));
            agent_we_out   <= '1';
            curr_state_r   <= read_conf;
            
          else
            -- Keep the old values (=adst ddress) and stay in this state            
            curr_state_r <= wr_data;
          end if;


        when finish =>
          -- Notify that we're done.
          done_out       <= '1';
          agent_av_out   <= '0';
          agent_data_out <= (others => rst_value_arr(dbg_level*1));
          agent_comm_out <= (others => rst_value_arr(dbg_level*1));
          agent_we_out   <= '0';

        when others => null;
      end case;


    end if;
  end process main;
  

end rtl;
