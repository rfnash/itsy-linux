# [[file:~/ghq/github.com/rfnash/itsy-linux/README.org::*Makefile][Makefile:1]]
all: itsy-linux

itsy-linux: itsy-linux.asm
	nasm itsy-linux.asm -fbin -l itsy-linux.lst -o itsy-linux
	chmod +x itsy-linux
clean:
	rm itsy-linux.lst itsy-linux
# Makefile:1 ends here
