dist_man7_MANS = vyatta-autoinstall.7
BUILT_SOURCES = gen_man vyatta-autoinstall.7
CLEANFILES = vyatta-autoinstall.7 vyatta-autoinstall.7.html

gen_man:
	./get_vii.pl

vyatta-autoinstall.7: vyatta-autoinstall.7.ronn
	ronn $^
