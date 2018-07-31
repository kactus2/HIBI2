-------------------------------------------------
-- File        cfg_init_pkg.vhdl
-- Design
-- Description Package for  Hibi2 cfg_mem
-- 
--              This pkg contains the initial values for cfg parameters
--              
--              DO NOT COMPILE OR SYNTHESIZE THIS FILE FROM HIBI/VHDL
--              DIRECTORY.
--              COPY THIS TO YOUR WORK DIRECTORY AND MODIFY THAT COPY ONLY!
--              
-- Author :   	Erno salminen
-- e-mail       : erno.salminen@tut.fi
-- Date :   	16.12.2005
-- Project :	in the jungle

-- Modified :
-------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;


package cfg_init_pkg is
  
  

  -- Bounds for init arrys
  -- Wrappers can less or equal num of pages or slots
  constant max_n_tslots_c    : integer := 3;
  constant max_n_cfg_pages_c : integer := 2;

  type tframe_1d_arr_type is array (1 to max_n_cfg_pages_c) of integer;  --
                                                                         --note indexing
  type tslot_param_1d_arr_type is array (0 to max_n_tslots_c-1) of integer;
  type tslot_param_2d_array_type is array ( 1 to max_n_cfg_pages_c) of tslot_param_1d_arr_type;

  
  constant tframe_c : tframe_1d_arr_type := (100, 75);

  constant tslot_start_c : tslot_param_2d_array_type := ((10, 30, 40),
                                                         (12, 32, 42)
                                                         );

  constant tslot_stop_c : tslot_param_2d_array_type := ((18, 35, 85),
                                                         (6, 16, 36)
                                                         );

  constant tslot_id_c : tslot_param_2d_array_type := ((3, 4, 5),
                                                      (2, 3, 1)
                                                      );


  
end cfg_init_pkg;  

 

