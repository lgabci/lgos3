# LGOS3 emulator meson file

mkimg = find_program( 'mkimg.sh' )
qemu = find_program( 'qemu-system-i386' )

img_hd_ext2 = custom_target(
  'hd_ext2.img',
  output: 'hd_ext2.img',
  input: [ bootblock_mbr_bin, bootblock_ext2_bin, loader_bin, kernel ],
  command: [ mkimg, '@OUTPUT@', '@INPUT@', '100M', 'ext2', '@OUTDIR@' ],
  build_by_default: false
)

run_target(
  'qemu',
  command: [ qemu, '-cpu', '486', '-m', '1',
             '-drive', 'file=' + img_hd_ext2.full_path() + ',if=ide,bus=0,' +
                       'unit=0,media=disk,format=raw,id=hda',
             '-boot', 'order=c',
             '-parallel', 'none', '-serial', 'none', '-nic', 'none'
           ],
  depends: img_hd_ext2
)
