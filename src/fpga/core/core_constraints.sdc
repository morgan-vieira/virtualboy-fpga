#
# user core constraints
#
# put your clock groups in here as well as any net assignments
#

# The SDRAM's clock is an inverted copy of the CPU clock, forwarded to the pin
# through an output DDIO cell (pin_ddio_clk with datain_h=0 / datain_l=1, in
# core_top.v). Modeling it as a generated clock ON the port is what accounts
# for the clock network's insertion delay: without it the SDRAM pins are
# analyzed against the raw PLL output, which the data path never sees, and
# every pin reports a large fictitious skew. MiSTer's rtl/Mem/sdram.sdc
# records the same arrangement and the same reason.
set sdram_clk_source \
 {ic|mp1|mf_pllbase_inst|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk}

create_generated_clock -name dram_clk_pin -invert \
 -source [get_pins $sdram_clk_source] \
 [get_ports {dram_clk}]

if {[get_collection_size [get_clocks dram_clk_pin]] == 0} {
    post_message -type error "core_constraints.sdc: no dram_clk generated pin clock matched"
}

# Commands, addresses and write data leave on the controller's rising edge and
# are sampled by the part on the pin clock's rising edge half a period later.
# The inversion lives in the generated clock, so no -clock_fall qualifier
# belongs here. 1.5 ns setup and 0.8 ns hold are the part's input window.
set dram_out_ports [get_ports {dram_a[*] dram_ba[*] dram_dqm[*] dram_cke \
                               dram_ras_n dram_cas_n dram_we_n dram_dq[*]}]

set_output_delay -clock dram_clk_pin -max 1.500 $dram_out_ports
set_output_delay -clock dram_clk_pin -min -0.800 $dram_out_ports

# Read data is launched by the part tAC after a pin clock edge, so the
# forwarded clock is the right launch reference. 6.0 ns is tAC at CAS 2 and
# 2.5 ns is tOH.
set_input_delay -clock dram_clk_pin -max 6.000 [get_ports {dram_dq[*]}]
set_input_delay -clock dram_clk_pin -min 2.500 [get_ports {dram_dq[*]}]

set_clock_groups -asynchronous \
 -group { bridge_spiclk } \
 -group { clk_74a } \
 -group { clk_74b } \
 -group { ic|mp1|mf_pllbase_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { ic|mp1|mf_pllbase_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk } \
 -group { ic|mp1|mf_pllbase_inst|altera_pll_i|general[2].gpll~PLL_OUTPUT_COUNTER|divclk \
          dram_clk_pin } \
 -group { ic|mp1|mf_pllbase_inst|altera_pll_i|general[3].gpll~PLL_OUTPUT_COUNTER|divclk }
