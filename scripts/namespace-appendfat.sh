#!/bin/sh
set -eu

cd "$(git rev-parse --show-toplevel)"

source_files="fs/appendfat/cache.c fs/appendfat/dir.c fs/appendfat/fat.h fs/appendfat/fat_test.c fs/appendfat/fatent.c fs/appendfat/file.c fs/appendfat/inode.c fs/appendfat/misc.c fs/appendfat/namei_msdos.c fs/appendfat/namei_vfat.c fs/appendfat/nfs.c"
config_files="fs/appendfat/.kunitconfig fs/appendfat/Kconfig fs/appendfat/Makefile"

require_blob()
{
    file=$1
    expected=$2
    actual=$(git hash-object "fs/appendfat/$file")

    if [ "$actual" != "$expected" ]; then
        printf '%s\n' "refusing namespace transform: fs/appendfat/$file is not the pinned baseline" >&2
        printf '%s\n' "expected: $expected" >&2
        printf '%s\n' "actual:   $actual" >&2
        exit 1
    fi
}

# This is a one-shot provenance transform. Refuse to overwrite a later
# derivative after identity or append-allocation work has begun.
require_blob .kunitconfig 0a6971dbeccb000be7dcd424c09a89496df57de3
require_blob Kconfig 25fae1c83725bc9293c26e9191690241d77b1295
require_blob Makefile 2b034112690d8a176b84f259a98f868028336540
require_blob cache.c 1b87354e24ba3a519082934ca48e277c3405d09b
require_blob dir.c 35bdb62944a2eb9eaa91e562a2da245929887d7f
require_blob fat.h 61338413d9f3e404d6dc1ca1915f706913dbb6d4
require_blob fat_test.c 9583ce66dca3cdc1f783577c35bbd7676cb9bf2f
require_blob fatent.c f0801d99dd62aefee4f573cfda332e7201235c32
require_blob file.c 1c835ca5f21a51a10b35522b609092c8ba873ce6
require_blob inode.c f775a004cae1e2f7eec2b7977c8e11ea1652dfc2
require_blob misc.c e79762cf19754d19096b5a8d8b2f8b7ae6a31995
require_blob namei_msdos.c d46d1a3851f25f75b4f9e88c2376894731e5def5
require_blob namei_vfat.c da3e89c0b16ac8fd076d7f70eec50c682f043812
require_blob nfs.c 6e1b371711edd5aacb5a81092e32361bb255e86a

replace_token()
{
    old=$1
    new=$2
    shift 2

    OLD=$old NEW=$new perl -pi -e 's/(?<![A-Za-z0-9_])\Q$ENV{OLD}\E(?![A-Za-z0-9_])/$ENV{NEW}/g' "$@"
}

# Namespace only the source-level globals observed in the compiled collision
# inventory. Compiler-generated __pfx_* companions follow these names
# automatically and are intentionally not edited directly.
for symbol in \
    fat_add_cluster \
    fat_add_entries \
    fat_alloc_clusters \
    fat_alloc_new_dir \
    fat_attach \
    fat_block_truncate_page \
    fat_bmap \
    fat_build_inode \
    fat_cache_destroy \
    fat_cache_init \
    fat_cache_inval_inode \
    fat_chain_add \
    fat_clusters_flush \
    fat_count_free_clusters \
    fat_detach \
    fat_dir_empty \
    fat_dir_operations \
    fat_ent_access_init \
    fat_ent_read \
    fat_ent_write \
    fat_export_ops \
    fat_export_ops_nostale \
    fat_file_fsync \
    fat_file_inode_operations \
    fat_file_operations \
    fat_fileattr_get \
    fat_fill_inode \
    fat_fill_super \
    fat_flush_inodes \
    fat_free_clusters \
    fat_free_fc \
    fat_generic_ioctl \
    fat_get_cluster \
    fat_get_dotdot_entry \
    fat_get_mapped_cluster \
    fat_getattr \
    fat_iget \
    fat_init_fs_context \
    fat_param_spec \
    fat_parse_param \
    fat_reconfigure \
    fat_remove_entries \
    fat_scan \
    fat_scan_logstart \
    fat_search_long \
    fat_setattr \
    fat_subdirs \
    fat_sync_bhs \
    fat_time_fat2unix \
    fat_time_unix2fat \
    fat_trim_fs \
    fat_truncate_atime \
    fat_truncate_blocks \
    fat_truncate_time \
    fat_update_time
do
    replace_token "$symbol" "append${symbol}" $source_files
done

replace_token __fat_fs_error __appendfat_fs_error $source_files
replace_token _fat_msg _appendfat_msg $source_files

# Independent configuration namespace. Replace CONFIG_* uses and the bare
# Kconfig symbols separately; underscores prevent accidental substring edits.
replace_token CONFIG_FAT_FS CONFIG_APPENDFAT_FS $source_files $config_files
replace_token CONFIG_VFAT_FS CONFIG_APPENDFAT_VFAT_FS $source_files $config_files
replace_token CONFIG_MSDOS_FS CONFIG_APPENDFAT_MSDOS_FS $source_files $config_files
replace_token CONFIG_FAT_DEFAULT_CODEPAGE CONFIG_APPENDFAT_DEFAULT_CODEPAGE $source_files $config_files
replace_token CONFIG_FAT_DEFAULT_IOCHARSET CONFIG_APPENDFAT_DEFAULT_IOCHARSET $source_files $config_files
replace_token CONFIG_FAT_DEFAULT_UTF8 CONFIG_APPENDFAT_DEFAULT_UTF8 $source_files $config_files
replace_token CONFIG_FAT_KUNIT_TEST CONFIG_APPENDFAT_KUNIT_TEST $source_files $config_files

replace_token FAT_FS APPENDFAT_FS fs/appendfat/Kconfig
replace_token VFAT_FS APPENDFAT_VFAT_FS fs/appendfat/Kconfig
replace_token MSDOS_FS APPENDFAT_MSDOS_FS fs/appendfat/Kconfig
replace_token FAT_DEFAULT_CODEPAGE APPENDFAT_DEFAULT_CODEPAGE fs/appendfat/Kconfig
replace_token FAT_DEFAULT_IOCHARSET APPENDFAT_DEFAULT_IOCHARSET fs/appendfat/Kconfig
replace_token FAT_DEFAULT_UTF8 APPENDFAT_DEFAULT_UTF8 fs/appendfat/Kconfig
replace_token FAT_KUNIT_TEST APPENDFAT_KUNIT_TEST fs/appendfat/Kconfig

cat > fs/appendfat/Makefile <<'EOF'
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
EOF

cat > fs/appendfat/Kconfig <<'EOF'
# SPDX-License-Identifier: GPL-2.0-only
config APPENDFAT_FS
	tristate
	select BUFFER_HEAD
	select NLS
	select LEGACY_DIRECT_IO
	help
	  Common FAT-compatible core for the separately registered appendfat
	  filesystem derivatives. This starts from the pinned Linux FAT baseline;
	  append-specific allocation policy is intentionally not introduced here.

config APPENDFAT_MSDOS_FS
	tristate "appendfat MS-DOS name support"
	select APPENDFAT_FS
	help
	  Build the legacy 8.3-name derivative under the independent filesystem
	  name "appendmsdos". This preserves the baseline MS-DOS FAT behavior while
	  keeping stock Linux "msdos" separately selectable.

	  To compile this as a module, choose M here: the module is appendmsdos.

config APPENDFAT_VFAT_FS
	tristate "appendfat VFAT long-name support"
	select APPENDFAT_FS
	help
	  Build the long-filename FAT derivative under the independent filesystem
	  name "appendfat". At this stage its FAT behavior is intended to remain
	  identical to the pinned Linux VFAT baseline.

	  To compile this as a module, choose M here: the module is appendfat.

config APPENDFAT_DEFAULT_CODEPAGE
	int "Default codepage for appendfat"
	depends on APPENDFAT_FS
	default 437
	help
	  Default FAT codepage. It can be overridden with the codepage mount option.

config APPENDFAT_DEFAULT_IOCHARSET
	string "Default iocharset for appendfat"
	depends on APPENDFAT_VFAT_FS
	default "iso8859-1"
	help
	  Default input/output character set for appendfat long filenames. It can
	  be overridden with the iocharset mount option.

config APPENDFAT_DEFAULT_UTF8
	bool "Enable appendfat UTF-8 option by default"
	depends on APPENDFAT_VFAT_FS
	default n
	help
	  Enable the existing VFAT utf8 mount behavior by default for appendfat.

config APPENDFAT_KUNIT_TEST
	tristate "Unit tests for appendfat" if !KUNIT_ALL_TESTS
	depends on KUNIT && APPENDFAT_FS
	default KUNIT_ALL_TESTS
	help
	  Build the inherited FAT KUnit tests against the appendfat namespace.
EOF

# Independent externally visible filesystem identities. Internal vfat/msdos
# algorithm names remain unchanged unless they were actual global collisions.
perl -pi -e 's/\.name\s*=\s*"vfat"/.name\t\t= "appendfat"/' fs/appendfat/namei_vfat.c
perl -pi -e 's/MODULE_ALIAS_FS\("vfat"\)/MODULE_ALIAS_FS("appendfat")/' fs/appendfat/namei_vfat.c
perl -pi -e 's/MODULE_DESCRIPTION\("VFAT filesystem support"\)/MODULE_DESCRIPTION("appendfat VFAT-compatible filesystem support")/' fs/appendfat/namei_vfat.c

perl -pi -e 's/\.name\s*=\s*"msdos"/.name\t\t= "appendmsdos"/' fs/appendfat/namei_msdos.c
perl -pi -e 's/MODULE_ALIAS_FS\("msdos"\)/MODULE_ALIAS_FS("appendmsdos")/' fs/appendfat/namei_msdos.c
perl -pi -e 's/MODULE_DESCRIPTION\("MS-DOS filesystem support"\)/MODULE_DESCRIPTION("appendfat MS-DOS-compatible filesystem support")/' fs/appendfat/namei_msdos.c

perl -pi -e 's/MODULE_DESCRIPTION\("Core FAT filesystem support"\)/MODULE_DESCRIPTION("appendfat core FAT-compatible filesystem support")/' fs/appendfat/inode.c
perl -pi -e 's/\.name = "fat_test"/.name = "appendfat_test"/' fs/appendfat/fat_test.c
perl -pi -e 's/MODULE_DESCRIPTION\("KUnit tests for FAT filesystems"\)/MODULE_DESCRIPTION("KUnit tests for appendfat")/' fs/appendfat/fat_test.c

cat > fs/appendfat/.kunitconfig <<'EOF'
CONFIG_KUNIT=y
CONFIG_APPENDFAT_FS=y
CONFIG_APPENDFAT_MSDOS_FS=y
CONFIG_APPENDFAT_VFAT_FS=y
CONFIG_APPENDFAT_KUNIT_TEST=y
EOF

printf '%s\n' 'appendfat identity namespace applied'
