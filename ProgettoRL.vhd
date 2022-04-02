----------------------------------------------------------------------------------
--
-- Prova finale di Reti Logiche
-- Prof. W. Fornaciari
--
-- Developed by: Arturo Benedetti
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector (7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

-- output registri interni
signal rNum_out : std_logic_vector(7 downto 0);
signal rInIndex_out: std_logic_vector(7 downto 0);
signal rOutIndex_out : std_logic_vector(15 downto 0);
signal rInput_out : std_logic_vector(7 downto 0);
signal rOutput_out : std_logic_vector(15 downto 0);

signal fsm_state_out : std_logic_vector(1 downto 0);

-- segnali interni
signal sum_inIndex : std_logic_vector(7 downto 0);
signal sum_outIndex : std_logic_vector(15 downto 0);
signal fsm_state : std_logic_vector(1 downto 0);
signal output : std_logic_vector(15 downto 0);

-- mux, demux
signal mux_inIndex : std_logic_vector(7 downto 0);
signal mux_outIndex : std_logic_vector(15 downto 0);
signal mux_fsm_state : std_logic_vector(1 downto 0);

-- segnali controllo registri (load & sel)
signal rNum_load : std_logic;
signal rInput_load : std_logic;
signal rOutput_load : std_logic;
signal rInIndex_sel : std_logic;
signal rInIndex_load : std_logic;
signal rOutIndex_sel : std_logic;
signal rOutIndex_load : std_logic;
signal d_sel : std_logic;

signal fsm_state_load : std_logic;
signal fsm_state_sel : std_logic;

-- FSM
type S is (
    IDLE, SET_READ_ADDR, FETCH_READ_ADDR,
    SET_INPUT_INDEX, SET_INPUT_ADDR, READ_INPUT, COMPUTE,
    WRITE_RESULT_H, WRITE_RESULT_L,
    CHECK_END, NOTIFY_END, ENDING
);
signal cur_state, next_state : S;
signal o_end : std_logic;
    
begin
    --******************************* REGISTRI *******************************--
    
    sum_inIndex <= rInIndex_out + 1;
    sum_outIndex <= rOutIndex_out + 1;
        
    o_end <= '1' when rInIndex_out = rNum_out else '0';
    
    -- registro reg_num
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then rNum_out <= "00000000";
        elsif rising_edge(i_clk) then
            if(rNum_load = '1') then
                rNum_out <= i_data;
            end if;
        end if;
    end process;
    
    -- mux prima di fsm_state
    with fsm_state_sel select
        mux_fsm_state <=    "00" when '0',
                            fsm_state when '1',
                            "XX" when others;
    
    -- registro fsm_state
    process(i_clk, i_rst)
        begin
        if(i_rst = '1') then fsm_state_out <= "00";
        elsif rising_edge(i_clk) then
            if(fsm_state_load = '1') then
                fsm_state_out <= mux_fsm_state;
            end if;
        end if;
    end process;
    
    -- mux prima di reg_inIndex 
    with rInIndex_sel select
        mux_inIndex <=  "00000000" when '0',
                        sum_inIndex when '1',
                        "XXXXXXXX" when others;
    
    -- registro reg_inIndex       
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then rInIndex_out <= "00000000";
        elsif rising_edge(i_clk) then
            if(rInIndex_load = '1') then
                rInIndex_out <= mux_inIndex;
            end if;
        end if;
    end process;
    
    -- registro reg_input  
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then rInput_out <= "00000000";
        elsif rising_edge(i_clk) then
            if(rInput_load = '1') then
                rInput_out <= i_data;
            end if;
        end if;
    end process;
    
    -- mux prima di reg_outIndex 
    with rOutIndex_sel select
        mux_outIndex <= "0000001111101000" when '0',
                        sum_outIndex when '1',
                        "XXXXXXXXXXXXXXXX" when others;
     
    -- registro reg_outIndex       
    process(i_clk, i_rst)
    begin
     if(i_rst = '1') then rOutIndex_out <= "0000001111101000";
     elsif rising_edge(i_clk) then
         if(rOutIndex_load = '1') then
             rOutIndex_out <= mux_outIndex;
         end if;
     end if;
    end process;
    
    -- registro reg_output     
    process(i_clk, i_rst)
    begin
     if(i_rst = '1') then rOutput_out <= "0000000000000000";
     elsif rising_edge(i_clk) then
         if(rOutput_load = '1') then
             rOutput_out <= output;
         end if;
     end if;
    end process;
    
    -- mux prima di o_data
    with d_sel select
        o_data <=   rOutput_out(7 downto 0) when '0',
                    rOutput_out(15 downto 8) when '1',
                    "XXXXXXXX" when others;
    
    
    
    
    --******************************* MACCHINA A STATI *******************************--
    
    -- schema avanzamento stati
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then 
            cur_state <= IDLE;
        elsif rising_edge(i_clk) then
            cur_state <= next_state;
        end if;
    end process;
    
    -- gestione avanzamento stato
    process(cur_state, i_start, o_end)
    begin
        next_state <= cur_state;
        case cur_state is
            when IDLE =>
                if i_start = '1' then
                    next_state <= SET_READ_ADDR;
                end if;
                
            when SET_READ_ADDR => next_state <= FETCH_READ_ADDR;
                
            when FETCH_READ_ADDR =>
                next_state <= CHECK_END;
                
            when SET_INPUT_INDEX => 
                next_state <= SET_INPUT_ADDR;
                    
            when SET_INPUT_ADDR => 
                next_state <= READ_INPUT;
            
            when READ_INPUT =>    
                next_state <= COMPUTE;
                
            when COMPUTE =>
                next_state <= WRITE_RESULT_H;
                
            when WRITE_RESULT_H =>
                next_state <= WRITE_RESULT_L;
                
            when WRITE_RESULT_L =>
                next_state <= CHECK_END;
            
            when CHECK_END =>
                if o_end = '1' then
                    next_state <= NOTIFY_END;
                else next_state <= SET_INPUT_INDEX;
                end if;
            
            when NOTIFY_END =>
                if i_start = '0' then 
                    next_state <= ENDING;
                end if;
                
            when ENDING => 
                next_state <= IDLE;
        end case;
    end process;
    
    -- gestione operazioni degli stati
    process(cur_state, rInIndex_out, rOutIndex_out, rInput_out, fsm_state_out)
        variable state : integer;
        variable curBit : std_logic;
        variable result : std_logic_vector(15 downto 0);
    begin 
        o_address <= "0000000000000000";
        o_we <= '0';
        o_en <= '0';
        o_done <= '0';
        rNum_load <= '0';
        rInput_load <= '0';
        rOutput_load <= '0';
        rInIndex_sel <= '0';
        rInIndex_load <= '0';
        rOutIndex_sel <= '0';
        rOutIndex_load <= '0';
        d_sel <= '0';
        output <= "0000000000000000";
        fsm_state <= "00";
        fsm_state_load <= '0';
        fsm_state_sel <= '0';
        
        result := "0000000000000000";
        
        case cur_state is
            when IDLE =>
            when SET_READ_ADDR =>   o_address <= "0000000000000000";
                                    o_en <= '1';
                                    o_we <= '0';
                                    
                                    rInIndex_sel <= '0';
                                    rInIndex_load <= '1';
                                    rOutIndex_sel <= '0';
                                    rOutIndex_load <= '1';
                                    fsm_state_sel <= '0';
                                    fsm_state_load <= '1';
            when FETCH_READ_ADDR => rNum_load <= '1';
            when SET_INPUT_INDEX => rInIndex_sel <= '1';
                                    rInIndex_load <= '1';
            when SET_INPUT_ADDR =>  o_address <= ("00000000" & rInIndex_out);
                                    o_en <= '1';
                                    o_we <= '0';
            when READ_INPUT =>  rInput_load <= '1';
                                  
            -- computazione output convolutore            
            when COMPUTE =>
                state := to_integer(unsigned(fsm_state_out));
                
                for i in 7 downto 0 loop
                    curBit := rInput_out(i);
                    
                    case state is
                        when 0 =>
                            if curBit = '0' then
                                result(i * 2 + 1) := '0';
                                result(i * 2) := '0';
                                state := 0;
                            else
                                result(i * 2 + 1) := '1';
                                result(i * 2) := '1';
                                state := 2;
                            end if;
                        when 1 =>
                            if curBit = '0' then
                                result(i * 2 + 1) := '1';
                                result(i * 2) := '1';
                                state := 0;
                            else
                                result(i * 2 + 1) := '0';
                                result(i * 2) := '0';
                                state := 2;
                            end if;
                        when 2 =>
                            if curBit = '0' then
                                result(i * 2 + 1) := '0';
                                result(i * 2) := '1';
                                state := 1;
                            else
                                result(i * 2 + 1) := '1';
                                result(i * 2) := '0';
                                state := 3;
                            end if;
                        when 3 =>
                            if curBit = '0' then
                                result(i * 2 + 1) := '1';
                                result(i * 2) := '0';
                                state := 1;
                            else
                                result(i * 2 + 1) := '0';
                                result(i * 2) := '1';
                                state := 3;
                            end if;
                        when others =>
                    end case;
                end loop;
                
                output <= result;
                rOutput_load <= '1';
                fsm_state <= std_logic_vector(to_unsigned(state, 2));
                fsm_state_load <= '1';
                fsm_state_sel <= '1';
                
            when WRITE_RESULT_H =>  o_address <= rOutIndex_out;
                                    o_en <= '1';
                                    o_we <= '1';
                                    d_sel <= '1';
                                    rOutIndex_sel <= '1';
                                    rOutIndex_load <= '1';
                                    
            when WRITE_RESULT_L =>  o_address <= rOutIndex_out;
                                    o_en <= '1';
                                    o_we <= '1';
                                    d_sel <= '0';
                                    rOutIndex_sel <= '1';
                                    rOutIndex_load <= '1';
                                    
            when CHECK_END => 
            when NOTIFY_END => o_done <= '1';
            when ENDING => o_done <= '0';
        end case;
    end process;
    
end Behavioral;