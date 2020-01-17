# LGOS3 loader/loader file

executable('loader.elf',
  'loader.c', 'console.c', 'disk.c', 'elf.c', 'ext2.c', 'fat.c', 'init.s',
  'lib.c', 'multiboot.c',
  c_args: [ '-m16'
          ],
  link_args: [ '-T',
               meson.current_source_dir() + '/loader.ld'
             ]
)
