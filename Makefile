# [[file:~/ghq/github.com/rfnash/itsy-linux/README.org::*Makefile][Makefile:1]]
all: itsy-linux msdos/itsy.com

itsy-linux: itsy-linux.asm
	nasm itsy-linux.asm -fbin -l itsy-linux.lst -o itsy-linux
	chmod +x itsy-linux
msdos/itsy.com: msdos/itsy.asm
	nasm msdos/itsy.asm -fbin -l msdos/itsy.lst -o msdos/itsy.com
clean:
	rm -f itsy-linux.lst itsy-linux msdos/itsy.lst msdos/itsy.com
# Makefile:1 ends here
