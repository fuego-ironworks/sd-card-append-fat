# SPDX-License-Identifier: GPL-2.0
#
# Makefile for appendfat, initially derived from Linux FAT without semantic
# allocation changes.
#

obj-$(CONFIG_APPENDFAT_FS) += appendfat_core.o
obj-$(CONFIG_APPENDFAT_VFAT_FS) += appendfat.o
obj-$(CONFIG_APPENDFAT_MSDOS_FS) += appendmsdos.o

appendfat_core-y := cache.o dir.o fatent.o file.o inode.o misc.o nfs.o
appendfat-y := namei_vfat.o
appendmsdos-y := namei_msdos.o

obj-$(CONFIG_APPENDFAT_KUNIT_TEST) += appendfat_test.o
appendfat_test-y := fat_test.o
