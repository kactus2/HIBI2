-------------------------------------------------------------------------------
-- File        : hibi_bridge.vhdl
-- Description : Connects two HIBI buses together
-- Author      : Erno Salminen
-- e-mail      : erno.salminen@tut.fi
-- Project     : mikälie
-- Design      : Do not use term design when you mean system
-- Date        : 02.12.2002
-- Modified    : 
-- 
-- !NOTE! Counter width is missing -AK
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity hibi_bridge is

  generic (
    -- Bus A
    a_id_g          : integer := 0;
    a_base_id_g     : integer := 0;
    a_addr_g        : integer := 0;
    a_inv_addr_en_g : integer := 0;

    a_id_width_g      : integer := 0;
    a_addr_width_g    : integer := 0;   -- in words
    a_data_width_g    : integer := 0;   -- in bits
    a_comm_width_g    : integer := 0;
    a_counter_width_g : integer := 0;

    a_rx_fifo_depth_g     : integer := 0;
    a_tx_fifo_depth_g     : integer := 0;
    a_rx_msg_fifo_depth_g : integer := 0;
    a_tx_msg_fifo_depth_g : integer := 0;

    -- These 4 added 2007/04/17
    a_arb_type_g     : integer := 0;  -- 0 round-robin, 1 priority,2=prior+rr,3=rand 
    -- fifo_sel: 0 synch multiclk,         1 basic GALS,
    --           2 Gray FIFO (depth=2^n!), 3 mixed clock pausible
    a_fifo_sel_g     : integer := 0;
    a_multicast_en_g : integer := 0;
    a_debug_width_g  : integer := 0;

    a_prior_g          : integer := 0;
    a_max_send_g       : integer := 0;
    a_n_agents_g       : integer := 0;
    a_n_cfg_pages_g    : integer := 0;
    a_n_time_slots_g   : integer := 0;
    a_n_extra_params_g : integer := 0;
    a_cfg_re_g         : integer := 0;
    a_cfg_we_g         : integer := 0;

    -- Bus B    
    b_id_g          : integer := 0;
    b_base_id_g     : integer := 0;
    b_addr_g        : integer := 0;
    b_inv_addr_en_g : integer := 0;

    b_id_width_g      : integer := 0;
    b_addr_width_g    : integer := 0;   -- in words
    b_data_width_g    : integer := 0;   -- in bits
    b_comm_width_g    : integer := 0;
    b_counter_width_g : integer := 0;

    b_rx_fifo_depth_g     : integer := 0;
    b_tx_fifo_depth_g     : integer := 0;
    b_rx_msg_fifo_depth_g : integer := 0;
    b_tx_msg_fifo_depth_g : integer := 0;

    -- These 4 added 2007/04/17
    b_arb_type_g     : integer := 0;  -- 0 round-robin, 1 priority,2=prior+rr,3=rand 
    -- fifo_sel: 0 synch multiclk,         1 basic GALS,
    --           2 Gray FIFO (depth=2^n!), 3 mixed clock pausible
    b_fifo_sel_g     : integer := 0;
    b_multicast_en_g : integer := 0;
    b_debug_width_g  : integer := 0;

    b_prior_g          : integer := 0;
    b_max_send_g       : integer := 0;
    b_n_agents_g       : integer := 0;
    b_n_cfg_pages_g    : integer := 0;
    b_n_time_slots_g   : integer := 0;
    b_n_extra_params_g : integer := 0;
    b_cfg_re_g         : integer := 0;
    b_cfg_we_g         : integer := 0
    );

  port (
    a_clk   : in std_logic;
    a_rst_n : in std_logic;

    b_clk   : in std_logic;
    b_rst_n : in std_logic;

    a_bus_av_in   : in std_logic;
    a_bus_data_in : in std_logic_vector (a_data_width_g-1 downto 0);
    a_bus_comm_in : in std_logic_vector (a_comm_width_g-1 downto 0);
    a_bus_full_in : in std_logic;
    a_bus_lock_in : in std_logic;

    b_bus_av_in   : in std_logic;
    b_bus_data_in : in std_logic_vector (b_data_width_g-1 downto 0);
    b_bus_comm_in : in std_logic_vector (b_comm_width_g-1 downto 0);
    b_bus_full_in : in std_logic;
    b_bus_lock_in : in std_logic;

    a_bus_av_out   : out std_logic;
    a_bus_data_out : out std_logic_vector (a_data_width_g-1 downto 0);
    a_bus_comm_out : out std_logic_vector (a_comm_width_g-1 downto 0);
    a_bus_lock_out : out std_logic;
    a_bus_full_out : out std_logic;

    b_bus_av_out   : out std_logic;
    b_bus_data_out : out std_logic_vector (b_data_width_g-1 downto 0);
    b_bus_comm_out : out std_logic_vector (b_comm_width_g-1 downto 0);
    b_bus_lock_out : out std_logic;
    b_bus_full_out : out std_logic
    );

end hibi_bridge;


architecture rtl of hibi_bridge is

  component hibi_wrapper_r1
    generic (
      id_g          : integer := 0;
      base_id_g     : integer := 0;
      addr_g        : integer := 0;
      inv_addr_en_g : integer := 0;

      id_width_g      : integer := 0;
      addr_width_g    : integer := 0;   -- in words
      data_width_g    : integer := 0;   -- in bits
      comm_width_g    : integer := 0;
      counter_width_g : integer := 0;

      rel_agent_freq_g : integer := 1;
      rel_bus_freq_g   : integer := 1;
      arb_type_g       : integer := 0;  -- 0 round-robin, 1 priority

      -- fifo_sel: 0 synch multiclk,         1 basic GALS,
      --           2 Gray FIFO (depth=2^n!), 3 mixed clock pausible
      fifo_sel_g : integer := 0;

      rx_fifo_depth_g     : integer := 0;
      tx_fifo_depth_g     : integer := 0;
      rx_msg_fifo_depth_g : integer := 0;
      tx_msg_fifo_depth_g : integer := 0;

      prior_g          : integer := 0;
      max_send_g       : integer := 0;
      n_agents_g       : integer := 0;
      n_cfg_pages_g    : integer := 0;
      n_time_slots_g   : integer := 0;
      n_extra_params_g : integer := 0;


      multicast_en_g : integer := 0;
      cfg_re_g       : integer := 0;
      cfg_we_g       : integer := 0;
      debug_width_g  : integer := 0     -- 13.04.2007 AK

      );

    port (
      bus_clk        : in std_logic;
      agent_clk      : in std_logic;
      bus_sync_clk   : in std_logic;
      agent_sync_clk : in std_logic;
      rst_n          : in std_logic;

      bus_av_in   : in std_logic;
      bus_data_in : in std_logic_vector (data_width_g-1 downto 0);
      bus_comm_in : in std_logic_vector (comm_width_g-1 downto 0);
      bus_full_in : in std_logic;
      bus_lock_in : in std_logic;

      agent_av_in   : in std_logic;
      agent_data_in : in std_logic_vector (data_width_g-1 downto 0);
      agent_comm_in : in std_logic_vector (comm_width_g-1 downto 0);
      agent_we_in   : in std_logic;
      agent_re_in   : in std_logic;

      agent_msg_av_in   : in std_logic;
      agent_msg_data_in : in std_logic_vector (data_width_g-1 downto 0);
      agent_msg_comm_in : in std_logic_vector (comm_width_g-1 downto 0);
      agent_msg_we_in   : in std_logic;
      agent_msg_re_in   : in std_logic;

      bus_av_out   : out std_logic;
      bus_data_out : out std_logic_vector (data_width_g-1 downto 0);
      bus_comm_out : out std_logic_vector (comm_width_g-1 downto 0);
      bus_lock_out : out std_logic;
      bus_full_out : out std_logic;

      agent_av_out    : out std_logic;
      agent_data_out  : out std_logic_vector (data_width_g-1 downto 0);
      agent_comm_out  : out std_logic_vector (comm_width_g-1 downto 0);
      agent_empty_out : out std_logic;
      agent_one_d_out : out std_logic;
      agent_full_out  : out std_logic;
      agent_one_p_out : out std_logic;

      agent_msg_av_out    : out std_logic;
      agent_msg_data_out  : out std_logic_vector (data_width_g-1 downto 0);
      agent_msg_comm_out  : out std_logic_vector (comm_width_g-1 downto 0);
      agent_msg_empty_out : out std_logic;
      agent_msg_one_d_out : out std_logic;
      agent_msg_full_out  : out std_logic;
      agent_msg_one_p_out : out std_logic
      -- synthesis translate_off 
;
      debug_out           : out std_logic_vector(debug_width_g-1 downto 0);
      debug_in            : in  std_logic_vector(debug_width_g-1 downto 0)
      -- synthesis translate_on    
      );
  end component;  --hibi_wrapper;



  component read_fifo_async
    generic (
      data_width_g : integer := 0);
    port (
      rst_n : in std_logic;

      clk_fifo : in  std_logic;
      re_out   : out std_logic;
      empty_in : in  std_logic;
      --one_d_in  : in  std_logic;
      data_in  : in  std_logic_vector (data_width_g-1 downto 0);

      clk_reader : in  std_logic;
      re_in      : in  std_logic;
      empty_out  : out std_logic;
      one_d_out  : out std_logic;
      data_out   : out std_logic_vector (data_width_g-1 downto 0)
      );
  end component;  --read_fifo_async;


  signal puppu : std_logic;

  -- A-sillasta ulos
  signal a_c_d_from_a : std_logic_vector (1 + a_comm_width_g + a_data_width_g -1 downto 0);
  signal av_from_a    : std_logic;
  signal data_from_a  : std_logic_vector (a_data_width_g-1 downto 0);
  signal comm_from_a  : std_logic_vector (a_comm_width_g-1 downto 0);  --13.03.03 Command_type;
  signal full_from_a  : std_logic;
  signal one_p_from_a : std_logic;
  signal empty_from_a : std_logic;
  signal one_d_from_a : std_logic;

  -- A-sillan kattelylogiikasta komb.prosessille "A->B"
  signal data_a_HS  : std_logic_vector (a_data_width_g-1 downto 0);
  signal empty_hs_a : std_logic;
  signal one_d_a_HS : std_logic;
  -- Komb. pros "A->B":lta A-sillan kattelylogiikalle
  signal re_a_HS    : std_logic;



  -- A-sillalle sisaan
  signal a_c_d_to_a : std_logic_vector (1 + a_comm_width_g + a_data_width_g-1 downto 0);
  signal av_to_a    : std_logic;
  signal data_to_a  : std_logic_vector (a_data_width_g-1 downto 0);
  signal comm_to_a  : std_logic_vector (a_comm_width_g-1 downto 0);  --13.03.03 command_type;
  signal we_to_a    : std_logic;
  signal re_to_a    : std_logic;

  signal Msg_av_to_a      : std_logic;
  signal Msg_data_to_a    : std_logic_vector (a_data_width_g-1 downto 0);
  signal Msg_comm_to_a    : std_logic_vector (a_comm_width_g-1 downto 0);  --13.03.03 command_type;
  signal Msg_we_to_a      : std_logic;
  signal Msg_re_to_a      : std_logic;
  signal Msg_full_From_b  : std_logic;
  signal Msg_one_p_from_b : std_logic;
  signal Msg_empty_from_b : std_logic;
  signal Msg_one_d_from_b : std_logic;







  -- b- sillalta ulos
  signal a_c_d_from_b : std_logic_vector (1 + a_comm_width_g + a_data_width_g-1 downto 0);
  signal av_From_b    : std_logic;
  signal data_from_b  : std_logic_vector (a_data_width_g-1 downto 0);
  signal comm_From_b  : std_logic_vector (a_comm_width_g-1 downto 0);
  signal full_From_b  : std_logic;
  signal one_p_from_b : std_logic;
  signal empty_from_b : std_logic;
  signal one_d_from_b : std_logic;

  -- b-sillalle sisaan
  signal a_c_d_to_b : std_logic_vector (1 + a_comm_width_g + a_data_width_g-1 downto 0);
  signal av_to_b    : std_logic;
  signal data_to_b  : std_logic_vector (a_data_width_g-1 downto 0);
  signal comm_to_b  : std_logic_vector (a_comm_width_g-1 downto 0);
  signal we_to_b    : std_logic;
  signal re_to_b    : std_logic;

  signal Msg_av_a_to_b    : std_logic;
  signal Msg_data_a_to_b  : std_logic_vector (a_data_width_g-1 downto 0);
  signal Msg_comm_a_to_b  : std_logic_vector (a_comm_width_g-1 downto 0);
  signal Msg_full_from_a  : std_logic;
  signal Msg_one_p_from_a : std_logic;
  signal Msg_empty_from_a : std_logic;
  signal Msg_one_d_from_a : std_logic;
  signal Msg_we_to_b      : std_logic;
  signal Msg_re_to_b      : std_logic;

  -- B-sillan kattelylogiikasta komb.prosessille "B->A"
  signal data_b_HS  : std_logic_vector (b_data_width_g-1 downto 0);
  signal empty_hs_b : std_logic;
  signal one_d_b_HS : std_logic;
  -- Komb. pros "B->A":lta B-sillan kattelylogiikalle
  signal re_b_HS    : std_logic;



begin  -- rtl

  assert a_comm_width_g = b_comm_width_g report "Command widths do not match" severity warning;

  HibiWrapper_a : hibi_wrapper_r1
    generic map (
      id_g          => a_id_g,
      base_id_g     => a_base_id_g,
      addr_g        => a_addr_g,
      inv_addr_en_g => a_inv_addr_en_g,

      id_width_g      => a_id_width_g,
      addr_width_g    => a_addr_width_g,
      data_width_g    => a_data_width_g,
      comm_width_g    => a_comm_width_g,
      counter_width_g => a_counter_width_g,

      -- These 6 added 2007/04/17
      rel_agent_freq_g => 1,                 -- fully synchronous 2007/04/17
      rel_bus_freq_g   => 1,                 -- fully synchronous2007/04/17
      arb_type_g       => a_arb_type_g,      -- 2007/04/17
      fifo_sel_g       => a_fifo_sel_g,      --2007/04/17
      multicast_en_g   => a_multicast_en_g,  --2007/04/17
      debug_width_g    => a_debug_width_g,   --2007/04/17

      rx_fifo_depth_g     => a_rx_fifo_depth_g,
      rx_msg_fifo_depth_g => a_rx_msg_fifo_depth_g,
      tx_fifo_depth_g     => a_tx_fifo_depth_g,
      tx_msg_fifo_depth_g => a_tx_msg_fifo_depth_g,

      prior_g          => a_prior_g,
      max_send_g       => a_max_send_g,
      n_agents_g       => a_n_agents_g,
      n_cfg_pages_g    => a_n_cfg_pages_g,
      n_time_slots_g   => a_n_time_slots_g,
      n_extra_params_g => a_n_extra_params_g,
      cfg_re_g         => a_cfg_re_g,
      cfg_we_g         => a_cfg_we_g

      )
    port map (
      clk   => a_clk,
      rst_n => a_rst_n,

      bus_comm_in => a_bus_comm_in,
      bus_data_in => a_bus_data_in,
      bus_full_in => a_bus_full_in,
      bus_lock_in => a_bus_lock_in,
      bus_av_in   => a_bus_av_in,

      agent_av_in       => av_to_a,
      agent_data_in     => data_to_a,
      agent_comm_in     => comm_to_a,
      agent_we_in       => we_to_a,
      agent_re_in       => re_to_a,
      agent_msg_av_in   => Msg_av_to_a,
      agent_msg_data_in => Msg_data_to_a,
      agent_msg_comm_in => Msg_comm_to_a,
      agent_msg_we_in   => Msg_we_to_a,
      agent_msg_re_in   => Msg_re_to_a,

      bus_comm_out => a_bus_comm_out,
      bus_data_out => a_bus_data_out,
      bus_full_out => a_bus_full_out,
      bus_lock_out => a_bus_lock_out,
      bus_av_out   => a_bus_av_out,

      agent_comm_out  => comm_from_a,
      agent_data_out  => data_from_a,
      agent_av_out    => av_from_a,
      agent_full_out  => full_from_a,
      agent_one_p_out => one_p_from_a,
      agent_empty_out => empty_from_a,
      agent_one_d_out => one_d_from_a,

      agent_msg_comm_out  => Msg_comm_a_to_b,
      agent_msg_data_out  => Msg_data_a_to_b,
      agent_msg_av_out    => Msg_av_a_to_b,
      agent_msg_full_out  => Msg_full_from_a,
      agent_msg_one_p_out => Msg_one_p_from_a,
      agent_msg_empty_out => Msg_empty_from_a,
      agent_msg_one_d_out => Msg_one_d_from_a
      );




  HibiWrapper_b : hibi_wrapper_r1
    generic map (
      id_g          => b_id_g,
      base_id_g     => b_base_id_g,
      addr_g        => b_addr_g,
      inv_addr_en_g => b_inv_addr_en_g,

      id_width_g      => b_id_width_g,
      addr_width_g    => b_addr_width_g,
      data_width_g    => b_data_width_g,
      comm_width_g    => b_comm_width_g,
      counter_width_g => b_counter_width_g,

      rx_fifo_depth_g     => b_rx_fifo_depth_g,
      rx_msg_fifo_depth_g => b_rx_msg_fifo_depth_g,
      tx_fifo_depth_g     => b_tx_fifo_depth_g,
      tx_msg_fifo_depth_g => b_tx_msg_fifo_depth_g,

      -- These 6 added 2007/04/17
      rel_agent_freq_g => 1,                 -- fully synchronous 2007/04/17
      rel_bus_freq_g   => 1,                 -- fully synchronous2007/04/17
      arb_type_g       => b_arb_type_g,      -- 2007/04/17
      fifo_sel_g       => b_fifo_sel_g,      --2007/04/17
      multicast_en_g   => b_multicast_en_g,  --2007/04/17
      debug_width_g    => b_debug_width_g,   --2007/04/17

      prior_g          => b_prior_g,
      max_send_g       => b_max_send_g,
      n_agents_g       => b_n_agents_g,
      n_cfg_pages_g    => b_n_cfg_pages_g,
      n_time_slots_g   => b_n_time_slots_g,
      n_extra_params_g => b_n_extra_params_g,
      cfg_re_g         => b_cfg_re_g,
      cfg_we_g         => b_cfg_we_g
      )
    port map (
      clk         => b_clk,
      rst_n       => b_rst_n,
      bus_comm_in => b_bus_comm_in,
      bus_data_in => b_bus_data_in,
      bus_full_in => b_bus_full_in,
      bus_lock_in => b_bus_lock_in,
      bus_av_in   => b_bus_av_in,

      agent_comm_in => comm_to_b,
      agent_data_in => data_to_b,
      agent_av_in   => av_to_b,
      agent_we_in   => we_to_b,
      agent_re_in   => re_to_b,

      agent_msg_comm_in => Msg_comm_a_to_b,
      agent_msg_data_in => Msg_data_a_to_b,
      agent_msg_av_in   => Msg_av_a_to_b,
      agent_msg_we_in   => Msg_we_to_b,
      agent_msg_re_in   => Msg_re_to_b,

      bus_comm_out => b_bus_comm_out,
      bus_data_out => b_bus_data_out,
      bus_full_out => b_bus_full_out,
      bus_lock_out => b_bus_lock_out,
      bus_av_out   => b_bus_av_out,

      agent_comm_out  => comm_From_b,
      agent_data_out  => data_from_b,
      agent_av_out    => av_From_b,
      agent_full_out  => full_From_b,
      agent_one_p_out => one_p_from_b,
      agent_empty_out => empty_from_b,
      agent_one_d_out => one_d_from_b,

      agent_msg_comm_out  => Msg_comm_to_a,
      agent_msg_data_out  => Msg_data_to_a,
      agent_msg_av_out    => Msg_av_to_a,
      agent_msg_full_out  => Msg_full_From_b,
      agent_msg_one_p_out => Msg_one_p_from_b,
      agent_msg_empty_out => Msg_empty_from_b,
      agent_msg_one_d_out => Msg_one_d_from_b
      );

  -- Continuous assignments
  a_c_d_from_a (1 + a_comm_width_g + a_data_width_g -1)                   <= av_from_a;
  a_c_d_from_a (a_comm_width_g + a_data_width_g -1 downto a_data_width_g) <= comm_from_a;
  a_c_d_from_a (a_data_width_g -1 downto 0)                               <= data_from_a;

  av_to_b   <= a_c_d_to_b (1+ a_comm_width_g + a_data_width_g -1);
  comm_to_b <= a_c_d_to_b (a_comm_width_g + a_data_width_g -1 downto a_data_width_g);
  data_to_b <= a_c_d_to_b (a_data_width_g -1 downto 0);

  a_c_d_from_b (1 + a_comm_width_g + a_data_width_g -1)                   <= av_from_b;
  a_c_d_from_b (a_comm_width_g + a_data_width_g -1 downto a_data_width_g) <= comm_from_b;
  a_c_d_from_b (a_data_width_g -1 downto 0)                               <= data_from_b;

  av_to_a   <= a_c_d_to_a (1+ a_comm_width_g + a_data_width_g -1);
  comm_to_a <= a_c_d_to_a (a_comm_width_g + a_data_width_g -1 downto a_data_width_g);
  data_to_a <= a_c_d_to_a (a_data_width_g -1 downto 0);

  Read_async_a : read_fifo_async
    generic map (
      data_width_g => (1+ a_comm_width_g+ a_data_width_g)
      )
    port map (
      Clk_Fifo => a_clk,
      Rst_n    => a_rst_n,
      re_Out   => re_to_a,
      Empty_In => empty_from_a,
      data_In  => a_c_d_from_a,

      Clk_Reader => b_clk,
      re_In      => re_b_hs,
      one_d_Out  => puppu,
      Empty_Out  => empty_hs_b,
      data_Out   => a_c_d_to_b
      );

  Read_async_b : read_fifo_async
    generic map (
      data_width_g => (1+ b_comm_width_g+ b_data_width_g)
      )
    port map (
      Clk_Fifo => b_clk,
      Rst_n    => b_rst_n,
      re_Out   => re_to_b,
      Empty_In => empty_from_b,
      data_In  => a_c_d_from_b,

      Clk_Reader => a_clk,
      re_In      => re_a_hs,
      --      one_d_Out  => puppu,
      Empty_Out  => empty_hs_a,
      data_Out   => a_c_d_to_a
      );


  A_to_b : process (empty_hs_a, full_from_a, Msg_empty_from_a, Msg_full_From_b)
  begin  -- process A_to_b
    if empty_hs_a = '0' and full_from_a = '0' then
      re_a_hs <= '1';
      we_to_a <= '1';
    else
      re_a_hs <= '0';
      we_to_a <= '0';
    end if;

--if Msg_empty_h = '0' and Msg_full_From_b = '0' then
--       Msg_re_to_a  <= '1';
--       Msg_we_to_b <= '1';
--     else
--       Msg_re_to_a  <= '0';
--       Msg_we_to_b <= '0';
--     end if;
  end process A_to_b;


  b_to_a : process (empty_hs_b, full_from_b, Msg_empty_from_b, Msg_full_from_a)
  begin  -- process b_to_a
    if empty_hs_b = '0' and full_from_b = '0' then
      re_b_hs <= '1';
      we_to_b <= '1';
    else
      re_b_hs <= '0';
      we_to_b <= '0';
    end if;

--    if Msg_empty_from_b = '0' and Msg_full_from_a = '0' then
--      Msg_re_to_b <= '1';
--      Msg_we_to_a <= '1';
--    else
--      Msg_re_to_b <= '0';
--      Msg_we_to_a <= '0';
--    end if;
  end process b_to_a;

  
end rtl;






































































