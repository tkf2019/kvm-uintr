KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(CURDIR)
BUILD_DIR := $(PWD)/build

obj-m += kvm-uintr.o
kvm-uintr-y := src/kvm_uintr_main.o

.PHONY: all clean prepare

all: prepare
	$(MAKE) -C $(KDIR) M=$(PWD) MO=$(BUILD_DIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) MO=$(BUILD_DIR) clean
	$(RM) -r $(BUILD_DIR)

prepare:
	mkdir -p $(BUILD_DIR)
