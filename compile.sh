#!/bin/bash

# Compile one instance of the kernel along with harness.
set -ex
cp -R "$1" "$2"
cd "$2/linux"
debian/rules clean
yes n | debian/rules genconfigs
cp CONFIGS/amd64-config.flavour.generic .config
make CC=$COMPILER olddefconfig

# AFL compilation results in undefined symbol issues, ignore all checks for this
find -name Makefile -exec sed -i 's/--no-undefined/--unresolved-symbols=ignore-all/g' {} \;
find -name checkundef.sh -exec /bin/sh -c 'echo -n "#!/bin/bash\ntrue" > {}' \;
sed -i 's#fail("vdso image contains#;//#g' arch/x86/entry/vdso/vdso2c.h

# Lib C and kernel uses different stack alignment, jump alignment etc.
# Lines below removes special flags that are used by kernel normally
# TODO All below are actually for the arch/x86/Makefile, make it a patch instead
find -name Makefile -exec sed -i 's/KBUILD_CFLAGS += -mno-sse -mno-mmx -mno-sse2 -mno-3dnow -mno-avx/#KBUILD_CFLAGS += -mno-sse -mno-mmx -mno-sse2 -mno-3dnow -mno-avx/g' {} \;
find -name Makefile -exec sed -i 's/KBUILD_CFLAGS += -mno-red-zone/#KBUILD_CFLAGS += -mno-red-zone/g' {} \;
find -name Makefile -exec sed -i 's/KBUILD_CFLAGS += -mcmodel=kernel/#KBUILD_CFLAGS += -mcmodel=kernel/g' {} \;
find -name Makefile -exec sed -i 's/KBUILD_CFLAGS += -mno-80387/#KBUILD_CFLAGS += -mno-80387/g' {} \;
# TODO: using -O2 as I for unknown reasons got issues with leaving it empty
find -name Makefile -exec sed -i 's/-mno-fp-ret-in-387/-O2/g' {} \;
find -name Makefile -exec sed -i 's/-mskip-rax-setup/-O2/g' {} \;
find -name Makefile -exec sed -i 's/-falign-jumps=1/-O2/g' {} \;
find -name Makefile -exec sed -i 's/-mstack-alignment=8/-O2/g' {} \;
find -name Makefile -exec sed -i 's/-mstack-alignment=4/-O2/g' {} \;
find -name Makefile -exec sed -i 's/-mpreferred-stack-boundary=3/-O2/g' {} \;
find -name Makefile -exec sed -i 's/-mpreferred-stack-boundary=2/-O2/g' {} \;
# End arch/x86/Makefile
find -name Makefile -exec sed -i 's/-Wno-sign-compare/-O2/g' {} \;
# End Lib C compatibility

# These are struct flags, remove them to make life easier
find -name '*.h' -exec sed -i 's/__attribute__((randomize_layout))//g' {} \;
find -name '*.h' -exec sed -i 's/__attribute__((__designated_init__))//g' {} \;

# Lots of kernel config options that disable security features and allow us to use the object files
scripts/config --set-str SYSTEM_TRUSTED_KEYS ""
scripts/config --set-str SYSTEM_REVOCATION_KEYS ""
scripts/config --set-val CONFIG_FRAME_WARN 2048
scripts/config --disable CONFIG_PARAVIRT
scripts/config --disable CONFIG_KVM_GUEST
scripts/config --disable CONFIG_STACKPROTECTOR

## https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project/Recommended_Settings
scripts/config --disable CONFIG_PARAVIRT
scripts/config --disable CONFIG_KVM_GUEST
scripts/config --disable CONFIG_STACKPROTECTOR
scripts/config --disable CONFIG_STRICT_KERNEL_RWX 
scripts/config --disable CONFIG_STRICT_MODULE_RWX 
scripts/config --disable CONFIG_RANDOMIZE_BASE   
scripts/config --disable CONFIG_RANDOMIZE_MEMORY
scripts/config --disable CONFIG_INTEL_IOMMU     
scripts/config --disable CONFIG_HAVE_FENTRY
scripts/config --disable CONFIG_FTRACE
scripts/config --disable CONFIG_STACKTRACE
scripts/config --disable CONFIG_GCC_PLUGIN_STRUCTLEAK
scripts/config --disable CONFIG_GCC_PLUGIN_STACKLEAK 
scripts/config --disable CONFIG_GCC_PLUGIN_RANDSTRUCT
scripts/config --disable CONFIG_DEBUG_WX             
scripts/config --disable CONFIG_STACKPROTECTOR_STRONG
scripts/config --disable CONFIG_STRICT_DEVMEM        
scripts/config --disable CONFIG_HARDENED_USERCOPY
scripts/config --disable CONFIG_SLAB_FREELIST_RANDOM
scripts/config --disable CONFIG_SHUFFLE_PAGE_ALLOCATOR
scripts/config --disable CONFIG_PAGE_POISONING        
scripts/config --disable CONFIG_REFCOUNT_FULL 
scripts/config --disable CONFIG_UBSAN        
scripts/config --disable CONFIG_KASAN        
scripts/config --disable CONFIG_KFENCE

## https://www.kernel.org/doc/html/v4.9/dev-tools/kmemcheck.html
scripts/config --disable CONFIG_CC_OPTIMIZE_FOR_SIZE
scripts/config --disable CONFIG_FUNCTION_TRACER
scripts/config --disable CONFIG_DEBUG_PAGEALLOC
scripts/config --disable CONFIG_WERROR
scripts/config --enable CONFIG_EXPERT
scripts/config --enable CONFIG_SLOB
scripts/config --enable CONFIG_INIT_STACK_NONE
scripts/config --enable CONFIG_CALL_PADDING
scripts/config --disable CONFIG_SLUB
scripts/config --disable CONFIG_FORTIFY_SOURCE
scripts/config --disable CONFIG_FUNCTION_GRAPH_TRACER
scripts/config --disable CONFIG_CPU_FREQ
scripts/config --disable CONFIG_HARDENED_USERCOPY
scripts/config --disable CONFIG_JUMP_LABEL
scripts/config --disable CONFIG_HOTPLUG_CPU
scripts/config --enable CONFIG_X86_64 
scripts/config --enable CONFIG_64BIT 
scripts/config --disable CONFIG_RETPOLINE
# Additional
scripts/config --enable CONFIG_DEBUG_INFO_DWARF5
scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
scripts/config --disable CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
scripts/config --disable CONFIG_HAVE_GENERIC_VDSO
scripts/config --disable CONFIG_VDSO
scripts/config --disable CONFIG_X86_32
scripts/config --disable CONFIG_X86_X32
scripts/config --disable CONFIG_IA32_EMULATION
scripts/config --disable CONFIG_X86_X32_ABI
echo '# CONFIG_INIT_STACK_ALL_PATTERN is not set' >> .config
echo '# CONFIG_INIT_STACK_ALL_ZERO is not set' >> .config


# The minor kernel patch needed to make fuzzing target visible in the obj file
patch --strip 1  < ../kernel.patch

# Compile the kernel, ignore all unresolved symbols
make KCFLAGS="$CFLAGS -g" CC=$COMPILER OBJDUMP=/usr/bin/true LD="ld --unresolved-symbols=ignore-all" -j16 || true
make KCFLAGS="$CFLAGS -g" CC=$COMPILER OBJDUMP=/usr/bin/true LD="ld --unresolved-symbols=ignore-all" -j16 lib || true

cd "$2"

# Final build line
# List of .o files generated using needed.py
$COMPILER $CFLAGS -O2 -g -static -Wl,--warn-unresolved-symbols -Wl,--unresolved-symbols=report-all main.c  kernel-mocker.c linux/crypto/asymmetric_keys/pkcs8_parser.o linux/lib/asn1_decoder.o linux/crypto/asymmetric_keys/pkcs8.asn1.o linux/lib/oid_registry.o $FFLAGS -o "$3"
