SRC += avm_decrease.vhd
SRC += avm_master.vhd
SRC += avm_memory.vhd
SRC += avm_pause.vhd
SRC += tb_avm_decrease.vhd

WAVE = tb_avm_decrease.ghw
SAVE = tb_avm_decrease.gtkw

sim: $(SRC)
	ghdl -i --std=08 --work=work $(SRC)
	ghdl -m --std=08 -fexplicit tb_avm_decrease
	ghdl -r --std=08 tb_avm_decrease --assert-level=error --wave=$(WAVE) --stop-time=10us

show: $(WAVE)
	gtkwave $(WAVE) $(SAVE)


clean:
	rm -rf *.o
	rm -rf work-obj08.cf
	rm -rf tb_avm_decrease
	rm -rf $(WAVE)

