modname 	   := tcp_bbr_classic
src_in  	   := tcp_bbr.c
BUILD_DIR      ?= build
BUILD_DIR_ABS  := $(abspath $(BUILD_DIR))
src_out        := $(BUILD_DIR_ABS)/tcp_bbr_classic.c
KBUILD_FILE    := $(BUILD_DIR_ABS)/Kbuild

KVERSION 	   := $(shell uname -r)
KDIR     	   := /lib/modules/$(KVERSION)/build
MODVER         ?= $(shell uname -r | cut -d. -f1-2)
DKMS           ?= dkms
DKMS_MODNAME   ?= bbr-classic
DKMS_DEST      ?= /usr/src/$(DKMS_MODNAME)-$(MODVER)
KCONFIG        := /lib/modules/$(KVERSION)/build/.config
KERNEL_CC      := $(shell grep -qs '^CONFIG_CC_IS_CLANG=y' $(KCONFIG) && echo clang)
SRC_URL        := https://raw.githubusercontent.com/torvalds/linux/v$(MODVER)/net/ipv4/tcp_bbr.c

ifeq ($(KERNEL_CC),clang)
	LLVM_FLAGS := LLVM=1
endif
# Run recipe blocks in a single shell so multi-line shell constructs don't need line continuations.
.ONESHELL:
default: $(src_out)
	$(MAKE) -C $(KDIR) M=$(BUILD_DIR_ABS) $(LLVM_FLAGS) modules

$(BUILD_DIR_ABS):
	mkdir -p $(BUILD_DIR_ABS)

$(KBUILD_FILE): | $(BUILD_DIR_ABS)
	printf 'obj-m := $(modname).o\n' > $(KBUILD_FILE)

$(src_in):
	curl -sL -o $(src_in) "$(SRC_URL)"

$(src_out): $(src_in) $(KBUILD_FILE)
	cp $(src_in) $(src_out)
	# rename all occurrences of the string literal "bbr" to "bbr_classic" in the copied source file
	sed -i 's/"bbr"/"bbr_classic"/g' $(src_out)
	# rename struct to avoid symbol conflicts with in-tree BBR
	sed -i 's/struct bbr/struct bbr_classic/g' $(src_out)
	# replace BTF kfunc registration with a no-op to avoid build errors on kernels with CONFIG_DEBUG_INFO_BTF_MODULES
	sed -i 's/ret = register_btf_kfunc_id_set.*/ret = 0; \/\/ skip BTF kfunc registration (out-of-tree)/' $(src_out)
	header_file=""
	for candidate in "$(KDIR)/source/include/net/tcp.h" "$(KDIR)/include/net/tcp.h"; do
		if [ -f "$$candidate" ]; then
			header_file="$$candidate"
			break
		fi
	done
	# checks for BBRv3-patched kernels
	if [ -z "$$header_file" ]; then
		echo "WARNING: tcp.h not found, skipping min_tso_segs check" >&2
	elif ! grep -q "min_tso_segs" "$$header_file"; then
		sed -i 's/\.min_tso_segs/\/\/ .min_tso_segs/g' $(src_out)
	fi

clean:
	if [ -d "$(BUILD_DIR_ABS)" ]; then
		$(MAKE) -C $(KDIR) M=$(BUILD_DIR_ABS) $(LLVM_FLAGS) clean
	fi
	rm -rf $(BUILD_DIR_ABS)
	rm -f $(src_in)
	rm -f *.zst *.pkg.tar.*
	rm -rf pkg/ src/

load:
	-rmmod $(modname)
	insmod $(BUILD_DIR_ABS)/$(modname).ko

install:
	if [ ! -f "$(BUILD_DIR_ABS)/$(modname).ko" ]; then
		echo "ERROR: Module not built. Run 'make' first." >&2; exit 1
	fi
	install -Dm644 $(BUILD_DIR_ABS)/$(modname).ko /lib/modules/$(KVERSION)/kernel/net/ipv4/$(modname).ko
	depmod -a

uninstall:
	rm -f /lib/modules/$(KVERSION)/kernel/net/ipv4/$(modname).ko
	depmod -a

help:
	@echo "Available targets:"
	@printf "  %-24s - %s\n" "make" "Download tcp_bbr.c and build the module"
	@printf "  %-24s - %s\n" "make clean" "Remove build directory and downloaded tcp_bbr.c"
	@printf "  %-24s - %s\n" "sudo make load" "Load module for testing (insmod)"
	@printf "  %-24s - %s\n" "sudo make install" "Install module permanently (no DKMS)"
	@printf "  %-24s - %s\n" "sudo make uninstall" "Remove permanently installed module"
	@printf "  %-24s - %s\n" "sudo make dkms-install" "Install via DKMS (auto-rebuild on kernel update)"
	@printf "  %-24s - %s\n" "sudo make dkms-uninstall" "Remove DKMS installation"

dkms-src-install: $(src_in)
	mkdir -p '$(DKMS_DEST)'
	cp Makefile tcp_bbr.c '$(DKMS_DEST)'
	sed 's/@VERSION@/$(MODVER)/' dkms.conf > '$(DKMS_DEST)/dkms.conf'

dkms-build: dkms-src-install
	$(DKMS) build -m $(DKMS_MODNAME) -v $(MODVER)

dkms-install: dkms-build
	$(DKMS) install -m $(DKMS_MODNAME) -v $(MODVER)

dkms-uninstall:
	$(DKMS) remove -m $(DKMS_MODNAME) -v $(MODVER) --all
	rm -rf '$(DKMS_DEST)'

.PHONY: default clean help load install uninstall dkms-src-install dkms-build dkms-install dkms-uninstall
