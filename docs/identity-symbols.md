# appendfat identity collision inventory

Generated from the exact source baseline pinned to Linux commit `238650ef6c7c7cca08e032527329424c9fbd70e5`.

Both stock `fs/fat` and `fs/appendfat` were compiled into their linked module objects from that same kernel tree before this inventory was produced. The job intentionally stops before `.ko` modpost because a full-kernel `Module.symvers` is not needed to compare defined symbols. This is an identity/collision inventory, not an append-allocation behavior test.

## Build-name collisions

- common module: `fat.ko`
- VFAT module: `vfat.ko`
- MS-DOS module: `msdos.ko`
- registered filesystem names: `vfat` and `msdos`

These must become independent appendfat identities before stock FAT and appendfat can coexist.

## Defined global symbols shared by stock and exact copy

The list comes from `nm -g --defined-only` on the three linked module objects on each side. `init_module` and `cleanup_module` are module-loader boilerplate; the remaining shared globals require deliberate namespacing for a robust built-in/module coexistence boundary.

```text
__fat_fs_error
__pfx___fat_fs_error
__pfx__fat_msg
__pfx_cleanup_module
__pfx_fat_add_cluster
__pfx_fat_add_entries
__pfx_fat_alloc_clusters
__pfx_fat_alloc_new_dir
__pfx_fat_attach
__pfx_fat_block_truncate_page
__pfx_fat_bmap
__pfx_fat_build_inode
__pfx_fat_cache_destroy
__pfx_fat_cache_init
__pfx_fat_cache_inval_inode
__pfx_fat_chain_add
__pfx_fat_clusters_flush
__pfx_fat_count_free_clusters
__pfx_fat_detach
__pfx_fat_dir_empty
__pfx_fat_ent_access_init
__pfx_fat_ent_read
__pfx_fat_ent_write
__pfx_fat_file_fsync
__pfx_fat_fileattr_get
__pfx_fat_fill_inode
__pfx_fat_fill_super
__pfx_fat_flush_inodes
__pfx_fat_free_clusters
__pfx_fat_free_fc
__pfx_fat_generic_ioctl
__pfx_fat_get_cluster
__pfx_fat_get_dotdot_entry
__pfx_fat_get_mapped_cluster
__pfx_fat_getattr
__pfx_fat_iget
__pfx_fat_init_fs_context
__pfx_fat_parse_param
__pfx_fat_reconfigure
__pfx_fat_remove_entries
__pfx_fat_scan
__pfx_fat_scan_logstart
__pfx_fat_search_long
__pfx_fat_setattr
__pfx_fat_subdirs
__pfx_fat_sync_bhs
__pfx_fat_time_fat2unix
__pfx_fat_time_unix2fat
__pfx_fat_trim_fs
__pfx_fat_truncate_atime
__pfx_fat_truncate_blocks
__pfx_fat_truncate_time
__pfx_fat_update_time
__pfx_init_module
_fat_msg
cleanup_module
fat_add_cluster
fat_add_entries
fat_alloc_clusters
fat_alloc_new_dir
fat_attach
fat_block_truncate_page
fat_bmap
fat_build_inode
fat_cache_destroy
fat_cache_init
fat_cache_inval_inode
fat_chain_add
fat_clusters_flush
fat_count_free_clusters
fat_detach
fat_dir_empty
fat_dir_operations
fat_ent_access_init
fat_ent_read
fat_ent_write
fat_export_ops
fat_export_ops_nostale
fat_file_fsync
fat_file_inode_operations
fat_file_operations
fat_fileattr_get
fat_fill_inode
fat_fill_super
fat_flush_inodes
fat_free_clusters
fat_free_fc
fat_generic_ioctl
fat_get_cluster
fat_get_dotdot_entry
fat_get_mapped_cluster
fat_getattr
fat_iget
fat_init_fs_context
fat_param_spec
fat_parse_param
fat_reconfigure
fat_remove_entries
fat_scan
fat_scan_logstart
fat_search_long
fat_setattr
fat_subdirs
fat_sync_bhs
fat_time_fat2unix
fat_time_unix2fat
fat_trim_fs
fat_truncate_atime
fat_truncate_blocks
fat_truncate_time
fat_update_time
init_module
```

## Kernel-exported FAT symbols

These are explicitly exported by the copied source and therefore cannot retain the stock names in an independently loadable derivative.

```text
__fat_fs_error
fat_add_entries
fat_alloc_new_dir
fat_attach
fat_build_inode
fat_detach
fat_dir_empty
fat_fileattr_get
fat_fill_super
fat_flush_inodes
fat_free_clusters
fat_free_fc
fat_get_dotdot_entry
fat_getattr
fat_init_fs_context
fat_param_spec
fat_parse_param
fat_reconfigure
fat_remove_entries
fat_scan
fat_search_long
fat_setattr
fat_time_fat2unix
fat_time_unix2fat
fat_truncate_atime
fat_truncate_time
fat_update_time
```

## Identity-only next step

The first derivative change should rename module/configuration/filesystem identities and namespace the copied globals while leaving FAT parsing, allocation, mapping, directory, writeback, and on-disk behavior unchanged. A coexistence build must compile stock FAT and appendfat together from the same pinned kernel tree.
