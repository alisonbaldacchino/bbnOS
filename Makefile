####################################################
# Makefile for bbnOS Following the guide of OrangeS#
####################################################

## OS Detection
UNAME := $(shell uname)

## UEFI Flag
UEFI_KERNEL ?= true

## DIRs
BUILD_DIR		= build
MOUNT_POINT		= ${BUILD_DIR}/mnt

BOOT_DIR		= boot
INC_B_DIR		= boot/include

ifeq (${UEFI_KERNEL}, false)
KERNEL_DIR  = kernel/legacy
INC_K_DIR		= include/legacy
LIB_DIR			= lib/legacy
else
KERNEL_DIR  = kernel/uefi
INC_K_DIR		= include/uefi
LIB_DIR     = lib/uefi
endif
SCRIPT_DIR		= scripts

DIRS 			= ${BOOT_DIR} ${KERNEL_DIR} ${LIB_DIR}
MKDIR			= ${patsubst %, ${BUILD_DIR}/%, ${DIRS}}
MKDIR		  += ${BUILD_DIR}
MKDIR     += ${MOUNT_POINT}

## Programs, flags, etc
ASM				= nasm
CC				= clang
LD				= ld.lld
ASM_B_FLAGS		= -I ${INC_B_DIR}
ASM_K_FLAGS		= -g -I ${INC_K_DIR}
C_FLAGS			= -c -I ${INC_K_DIR} -fno-builtin -Wall -Wextra -fno-stack-protector -g

ifeq ($(UEFI_KERNEL), false)
LDFLAGS			= -T ${SCRIPT_DIR}/link.ld
else
LDFLAGS 		= -T ${SCRIPT_DIR}/uefi.ld -shared -Bsymbolic -nostdlib
endif

# Add macro if it is a UEFI kernel
ifeq ($(UEFI_KERNEL), true)
C_FLAGS += -DUEFI_KERNEL
ASM_K_FLAGS += -f elf64
else
C_FLAGS += -m32
ASM_K_FLAGS += -f elf32
endif

## This Program
ifeq (${UEFI_KERNEL}, false)
# For boot
BOOT_ASM		= ${BOOT_DIR}/boot.asm
BOOT        = ${BUILD_DIR}/${BOOT_DIR}/boot.bin

LOADER_ASM		= ${BOOT_DIR}/loader.asm
LOADER      	= ${BUILD_DIR}/${BOOT_DIR}/loader.bin
endif

# For kernel
ifeq (${UEFI_KERNEL}, false)
KERN_ASMS		= ${wildcard ${KERNEL_DIR}/*.asm}
KERN_ASM_OBJS	= ${patsubst %.asm, ${BUILD_DIR}/%.obj, ${KERN_ASMS}}
endif
KERN_C			= ${wildcard ${KERNEL_DIR}/*.c}
KERN_C_OBJS	    = ${patsubst %.c, ${BUILD_DIR}/%.o, ${KERN_C}}

# For lib
ifeq (${UEFI_KERNEL}, false)
LIB_ASMS		= ${wildcard ${LIB_DIR}/*.asm}
KERN_ASM_OBJS  += ${patsubst %.asm, ${BUILD_DIR}/%.obj, ${LIB_ASMS}}
endif
LIB_C			= ${wildcard ${LIB_DIR}/*.c}
KERN_C_OBJS    += ${patsubst %.c, ${BUILD_DIR}/%.o, ${LIB_C}}

# For the out kernel
KERNEL 			= ${BUILD_DIR}/kernel.bin

## The output image
IMG_OUT			= ${BUILD_DIR}/os.img

## Rewrite something for MacOS
ifeq ($(UNAME), Darwin)
CC 				= i386-elf-gcc
LD				= i386-elf-ld
endif

## rules

# all
all: all_aval_img

# (Optional QEMU)
qemu: img
	qemu-system-i386 -fda ${IMG_OUT}

qemu_gdb: img
	qemu-system-i386 -fda ${IMG_OUT} -s -S

# build the image
img: all_aval_img
	dd if=/dev/zero of=${IMG_OUT} bs=512 count=2880
	dd if=${BOOT} of=${IMG_OUT} bs=512 count=1 conv=notrunc
ifeq ($(UNAME), Linux)
	sudo mount -o loop ${IMG_OUT} ${MOUNT_POINT}
else
	hdiutil mount ${IMG_OUT} -mountpoint ${MOUNT_POINT}
endif
	sudo cp ${LOADER} ${MOUNT_POINT}
	sudo cp ${KERNEL} ${MOUNT_POINT}
ifeq ($(UNAME), Linux)
	sudo umount ${MOUNT_POINT}
else
	hdiutil unmount ${MOUNT_POINT}
endif

ifeq ($(UEFI_KERNEL), false)
all_aval_img: clean prepare ${BOOT} ${LOADER} ${KERNEL}
else
all_aval_img: clean prepare ${KERNEL}
endif

${BOOT}: ${BUILD_DIR}/%.bin: %.asm
	${ASM} ${ASM_B_FLAGS} -o $@ $<

${LOADER}: ${BUILD_DIR}/%.bin: %.asm
	${ASM} ${ASM_B_FLAGS} -o $@ $<

# FIXME: The linking sequence is important
#        To be specific, the kernel.o compiled from kernel.asm must be compiled first
ifeq ($(UEFI_KERNEL), false)
${KERNEL}: ${KERN_C_OBJS} ${KERN_ASM_OBJS}
else
${KERNEL}: ${KERN_C_OBJS}
endif
	${LD} ${LDFLAGS} -o ${KERNEL} ${KERN_ASM_OBJS} ${KERN_C_OBJS}

${KERN_C_OBJS}: ${BUILD_DIR}/%.o: %.c
	${CC} ${C_FLAGS} -o $@ $<

${KERN_ASM_OBJS}: ${BUILD_DIR}/%.obj: %.asm
	${ASM} ${ASM_K_FLAGS} -o $@ $<

# make necessary dirs
prepare:
	mkdir -p ${MKDIR}

# clean
clean:
	rm -rf ${BUILD_DIR}
