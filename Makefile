SRC += burst_ctrl.vhd
SRC += lfsr.vhd
SRC += avm_master.vhd
SRC += avm_master2.vhd
SRC += avm_pause.vhd
SRC += avm_master_general.vhd
SRC += avm_arbit.vhd
SRC += avm_decrease.vhd
SRC += avm_memory.vhd
SRC += avm_memory_pause.vhd
SRC += avm_cache.vhd
SRC += axi_avalon.vhd
SRC += avalon_axi.vhd


#DUT ?= burst_ctrl
#DUT ?= avm_decrease
#DUT ?= avalon_axi
#DUT ?= avm_arbit
#DUT ?= avm_pause
DUT ?= avm_cache
#DUT ?= avm_master2


TB = tb_$(DUT)
SRC += $(TB).vhd
WAVE = $(TB).ghw
SAVE = $(TB).gtkw

sim: $(SRC)
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 -fexplicit $(TB)
	ghdl -r --std=08 $(TB) -gG_CACHE_SIZE=8 -gG_REQ_PAUSE=2 -gG_RESP_PAUSE=2 --assert-level=error --wave=$(WAVE) --stop-time=50us

questa: $(SRC)
	vcom -2008 $(SRC)
	vsim $(TB)

show: $(WAVE)
	gtkwave $(WAVE) $(SAVE)

formal: $(DUT)_bmc/PASS
$(DUT)_bmc/PASS: $(DUT).sby $(DUT).psl $(DUT).vhd
	sby --yosys "yosys -m ghdl" -f $(DUT).sby

show_bmc:
	gtkwave $(DUT)_bmc/engine_0/trace.vcd $(DUT).gtkw

show_cover:
	gtkwave $(DUT)_cover/engine_0/trace.vcd $(DUT).gtkw

clean:
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf $(TB)
	rm -rf $(WAVE)

