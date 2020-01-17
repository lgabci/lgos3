# LGOS3 emulator meson file

custom_target('hd_ext2.img',
              output: 'hd_ext2.img',
              depends: [bootblock_mbr, bootblock_ext2],
              command: ['touch', '@OUTPUT@'],
              build_by_default: true
             )
