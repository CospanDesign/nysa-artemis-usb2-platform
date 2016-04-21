TARGET := nysa_pcie
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

obj-m := nysa_pcie.o
$(TARGET)-objs := base.o pcie_ctr.o

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean

install:
	sudo insmod ./${TARGET}.ko

remove:
	sudo rmmod ${TARGET}

