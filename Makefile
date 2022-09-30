SRC += burst_ctrl.vhd
SRC += avm_master.vhd
SRC += avm_pause.vhd
SRC += avm_master_general.vhd
SRC += avm_arbit.vhd
SRC += avm_decrease.vhd
SRC += avm_memory.vhd
SRC += avm_memory_pause.vhd
SRC += axi_avalon.vhd
SRC += avalon_axi.vhd

TB = tb_burst_ctrl
TB = tb_avm_decrease
TB = tb_avalon_axi
TB = tb_avm_arbit

SRC += $(TB).vhd
WAVE = $(TB).ghw
SAVE = $(TB).gtkw

sim: $(SRC)
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 -fexplicit $(TB)
	ghdl -r --std=08 $(TB) --assert-level=error --wave=$(WAVE) --stop-time=120us

questa: $(SRC)
	vcom -2008 $(SRC)
	vsim $(TB)

show: $(WAVE)
	gtkwave $(WAVE) $(SAVE)


clean:
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf $(TB)
	rm -rf $(WAVE)

