# LGOS3 loader/loader file

loader = executable('loader.elf',
                    'loader.c', 'console.c', 'disk.c', 'elf.c', 'ext2.c', 'fat.c', 'init.s',
                    'lib.c', 'multiboot.c',
                    c_args: [ '-m16'
                            ],
                    link_args: [ '-T',
                                 meson.current_source_dir() + '/loader.ld'
                               ]
                   )

loader_bin = custom_target('loader.bin',
                           output: 'loader.bin',
                           input: loader,
                           command: [objcopy, '-O', 'binary', '@INPUT@', '@OUTPUT@']
                          )
