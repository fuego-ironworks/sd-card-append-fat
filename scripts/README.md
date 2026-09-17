# Scripts

`import-linux-fat.sh` materializes the exact pinned Linux `fs/fat` baseline into `fs/appendfat/` and verifies every imported file by Git blob ID.

`verify-import-manifest.sh` checks that the blob inventory in `fs/appendfat/UPSTREAM.md` and the importer agree.

`namespace-appendfat.sh` applies the reviewed identity-only derivative transform. Its source-symbol substitutions are the explicit compiled collision inventory from `docs/identity-symbols.md`; compiler-generated `__pfx_*` names are not edited directly. It also creates the independent `APPENDFAT_*`, module, and filesystem-registration identities. It is not an allocation-policy transform.

`install-appendfat-into-linux.sh /path/to/linux` refuses any Linux tree except the exact pinned upstream commit, copies `fs/appendfat/` beside stock `fs/fat/`, and adds only the top-level Kconfig/Makefile hooks needed to build it.

These scripts preserve the evidence boundary: they do not establish mount equivalence, crash safety, Android/vendor-kernel compatibility, or physical-device acceptance.
