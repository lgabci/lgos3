# LGOS3 kernel file

executable('kernel.elf',
           'init.s', 'initc.c', 'paging.c', 'descript.c',
           c_args: [ '-Wa,-I,' + meson.current_source_dir()
                   ],
           link_args: [ '-T',
                        meson.current_source_dir() + '/kernel.ld'
                      ]
          )
