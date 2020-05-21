# LGOS3 loader/bootblock file

bootblock_mbr = executable('bootblock_mbr.elf',
  'init.s', 'bootblock_mbr.s', 'display.s', 'misc.s', 'disk.s',
  link_depends: ['bootblock_mbr.ld'],
  c_args: [ '-Wa,-I,' + meson.current_source_dir() ],
  link_args: [ '-T', meson.current_source_dir() + '/bootblock_mbr.ld' ]
)

bootblock_mbr_bin = custom_target('bootblock_mbr.bin',
  output: 'bootblock_mbr.bin',
  input: bootblock_mbr,
  command: [objcopy, '-O', 'binary', '@INPUT@', '@OUTPUT@']
)

bootblock_ext2 = executable('bootblock_ext2.elf',
  'init.s', 'bootblock_ext2.s', 'display.s', 'misc.s', 'disk.s', 'load.s',
  link_depends: ['bootblock_ext2.ld'],
  c_args: [ '-Wa,-I,' + meson.current_source_dir() ],
  link_args: [ '-T', meson.current_source_dir() + '/bootblock_ext2.ld' ]
)

bootblock_ext2_bin = custom_target('bootblock_ext2.bin',
  output: 'bootblock_ext2.bin',
  input: bootblock_ext2,
  command: [objcopy, '-O', 'binary', '@INPUT@', '@OUTPUT@']
)

bootblock_fat = executable('bootblock_fat.elf',
  'init.s', 'bootblock_fat.s', 'display.s', 'misc.s', 'disk.s', 'load.s',
  link_depends: ['bootblock_fat.ld'],
  c_args: [ '-Wa,-I,' + meson.current_source_dir() ],
  link_args: [ '-T', meson.current_source_dir() + '/bootblock_fat.ld' ]
)

bootblock_fat_bin = custom_target('bootblock_fat.bin',
  output: 'bootblock_fat.bin',
  input: bootblock_fat,
  command: [objcopy, '-O', 'binary', '@INPUT@', '@OUTPUT@']
)
