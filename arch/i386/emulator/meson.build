# LGOS3 emulator meson file

mkimg = find_program('mkimg.sh')

custom_target('hd_ext2.img',
              output: 'hd_ext2.img',
              input: [bootblock_mbr_bin, bootblock_ext2_bin, loader_bin, kernel],
              command: [mkimg, '@OUTPUT@', '@INPUT@', '100M', 'ext2', '@OUTDIR@'],
              build_by_default: true
             )
