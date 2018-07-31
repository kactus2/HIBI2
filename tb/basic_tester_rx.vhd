-------------------------------------------------------------------------------
-- Title      : A block which reads and checks data coming via HIBI
-- Project    : 
-------------------------------------------------------------------------------
-- File       : basic_test_rx.vhd
-- Author     : ege
-- Created    : 2010-03-30
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



library std;
use std.textio.all;
use work.txt_util.all;                  -- for function sgtr(std_log_vec)

use work.basic_test_pkg.all;            -- read_conf_file()

entity basic_test_rx is

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
    agent_av_in    : in  std_logic;
    agent_data_in  : in  std_logic_vector(data_width_g-1 downto 0);
    agent_comm_in  : in  std_logic_vector (comm_width_g-1 downto 0);
    agent_re_out   : out std_logic;
    agent_empty_in : in  std_logic;
    agent_one_d_in : in  std_logic
    );

end basic_test_rx;


architecture rtl of basic_test_rx is

  constant allow_more_data_than_in_file_c : integer := 0;

  type control_states is (read_conf, wait_data, rd_addr, rd_data, finish);
  signal curr_state_r : control_states := read_conf;

  signal re_r            : std_logic;
  signal last_addr_r     : std_logic_vector (data_width_g-1 downto 0);
  signal cycle_counter_r : integer;
  
  signal delay_r         : integer;
  signal dst_addr_r      : integer;
  signal data_val_r      : integer;
  signal comm_r          : integer;

  signal n_addr_r       : integer;
  signal n_data_r       : integer;
  signal addr_correct_r : std_logic;    -- 2010-10-08
  signal error_r        : std_logic;
  
  -- Registers may be reset to 'Z' to 'X' so that reset state is clearly
  -- distinguished from active state. Using dbg_level+Rst_Value array, the rst value may
  -- be easily set to '0' for synthesis.
  constant dbg_level     : integer range 0 to 3          := 0;  -- 0= no debug
  constant rst_value_arr : std_logic_vector (6 downto 0) := 'X' & 'Z' & 'X' & 'Z' & 'X' & 'Z' & '0';
  -- Right now gives a lot of warnings when other than 0

  
begin  -- rtl

  agent_re_out <= re_r;

  main : process (clk, rst_n)
    file conf_data_file : text open read_mode is conf_file_g;

    -- The read values from file are stored into these
    variable delay_v    : integer;
    variable dst_ag_v   : integer;
    variable data_val_v : integer;
    variable cmd_v      : integer;

  begin  -- process main
    
    if rst_n = '0' then                 -- asynchronous reset (active low)
      
      curr_state_r    <= read_conf;
      last_addr_r     <= (others => rst_value_arr (dbg_level * 1));
      cycle_counter_r <= 0;
      re_r            <= '0';
      done_out        <= '0';

      n_addr_r       <= 0;
      n_data_r       <= 0;
      addr_correct_r <= '0';
      error_r        <= '0';
                        
      delay_v        := 0;
      dst_ag_v       := 0;
      data_val_v     := 0;
      cmd_v          := 0;

    elsif clk'event and clk = '1' then  -- rising clock edge

      case curr_state_r is
        
        when read_conf =>
          -- Read the file to see what data should arrive next
          
          if endfile(conf_data_file) then
            curr_state_r   <= finish;
            re_r           <= '1';
            addr_correct_r <= '0';
            error_r        <= '0';
            assert false report "End of the configuration file reached" severity note;
          else
            read_conf_file (
              delay        => delay_v,
              dest_agent_n => dst_ag_v,
              value        => data_val_v,
              cmd          => cmd_v,
              conf_dat     => conf_data_file);

            delay_r         <= delay_v;
            dst_addr_r      <= dst_ag_v;
            data_val_r      <= data_val_v;
            comm_r          <= cmd_v;
            error_r         <= '0';
            re_r            <= '0';
            cycle_counter_r <= 0;
            curr_state_r    <= wait_data;

            
            if dst_ag_v /= 0 then
              addr_correct_r  <= '0';
            -- else keep the the old value  
            end if;

            
          end if;  -- endfile
          

        when wait_data =>

          if agent_empty_in = '0' then
            if agent_av_in = '1' then
              curr_state_r <= rd_addr;
            else
              if addr_correct_r = '1' then
                curr_state_r <= rd_data;
              else
                error_r <= '1';
                assert false report "Data received but addr could not be checked" severity warning;
                curr_state_r <= read_conf;
              end if;
            end if;
            re_r <= '1';
            
          else
            re_r            <= '0';
          end if;
          
          -- Increment the delay counter
          cycle_counter_r <= cycle_counter_r +1;

          
        when rd_addr =>

          -- Check the address
          addr_correct_r <= '1';        -- default that may be overriden

          
          if dst_addr_r = 0 then
            -- Assume that addr has not changed
            
            if agent_data_in /= last_addr_r then
              addr_correct_r <= '0';
              error_r        <= '1';

              --assert agent_data_in = last_addr_r
              assert false
                report "Addr does not match. Expected " & str(to_integer(signed(last_addr_r))) & " but got " & str(to_integer(unsigned(agent_data_in)))
                severity warning;

            end if;  

            
          elsif dst_addr_r /= -1 then
            --  Expected addr was given in the file

            if to_integer(unsigned(agent_data_in)) /= dst_addr_r then
              addr_correct_r <= '0';
              error_r        <= '1';

              --assert to_integer(unsigned(agent_data_in)) = dst_addr_r
              assert false
                report "Addr does not match. Expected 0d" & str(dst_addr_r) & " but got 0d" & str(to_integer(unsigned(agent_data_in)))
                severity warning;

            end if;
          end if;

          if comm_r /= -1 then

            if to_integer(unsigned(agent_comm_in)) /= comm_r then
              error_r <= '1';
              -- assert to_integer(unsigned(agent_comm_in)) = comm_r
              assert false
                report "Comm does not match  Expected 0d" & str(comm_r) & " but got 0d" & str(to_integer(unsigned(agent_comm_in)))
                severity warning;
            end if;
          end if;


          last_addr_r     <= agent_data_in;
          n_addr_r        <= n_addr_r +1;
          cycle_counter_r <= cycle_counter_r +1;


          if agent_empty_in = '0' then
            re_r         <= '1';
            curr_state_r <= rd_data;
          else
            re_r         <= '0';
            curr_state_r <= wait_data;
          end if;



          

        when rd_data =>
          re_r           <= '0';
          n_data_r       <= n_data_r +1;
          curr_state_r   <= read_conf;
          
          -- Check
          --  a) if data arrived before wait time has expired
          if delay_r /= -1 then

            if delay_r < cycle_counter_r then
              error_r <= '1';
              
              --assert delay_r >= cycle_counter_r
              assert false
                report "Data arrived too late. Expected duration " & str(delay_r) & " cycles, but it took " & str(cycle_counter_r) & " cycles."
                severity warning;
            end if;
          end if;

          --  b) if value is as expected
          if data_val_r /= -1 then
            if to_integer(signed(agent_data_in)) /= data_val_r then
              error_r <= '1';
              --assert to_integer(signed(agent_data_in)) = data_val_r
              assert false
                report "Wrong data value.  Expected 0d" & str(data_val_r) & " but got 0d" & str(to_integer(unsigned(agent_data_in)))
                severity warning;
            end if;
          end if;

          --  c) command is as expected

          if comm_r /= -1 then

            if to_integer(unsigned(agent_comm_in)) /= comm_r then
              error_r <= '1';
              -- assert to_integer(unsigned(agent_comm_in)) = comm_r
              assert false
                report "Comm does not match  Expected 0d" & str(comm_r) & " but got 0d" & str(to_integer(unsigned(agent_comm_in)))
                severity warning;
            end if;
          end if;

          

        when finish =>
          -- Notify that we're done.
          done_out        <= '1';
          cycle_counter_r <= 0;
          delay_r         <= 0;
          dst_addr_r      <= 0;
          data_val_r      <= 0;
          comm_r          <= 0;
          re_r            <= '1';
          
          if allow_more_data_than_in_file_c = 1 then
            -- Keep reading if some data still arrives
            -- but cannot check anything

            if agent_empty_in = '0' and re_r = '1' then
              if agent_av_in = '1' then
                n_addr_r    <= n_addr_r +1;
                last_addr_r <= agent_data_in;
              else
                n_data_r <= n_data_r +1;
              end if;
            end if;
          else
            -- There should not be anymore data
            if agent_empty_in = '0' then
              error_r <= '1';
              --assert agent_empty_in = '1' report "Unexpected data arrives" severity warning;
              assert false report "Unexpected data arrives" severity warning;
            end if;
            
            
          end if;

        when others => null;
      end case;


    end if;
  end process main;
  

end rtl;
